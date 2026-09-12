"""Real Zsh regressions for NUL selections and transactional plugin recovery."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
ZSH=os.environ.get("ZSH_BIN") or shutil.which("zsh")
BOOT='[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path); zmodload zsh/parameter || exit 1; '

@unittest.skipUnless(ZSH,"Zsh required")
class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="zsh-recovery-")
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()
        self.bin=self.root/"bin"
        self.bin.mkdir()
        self.plugins=self.root/"plugins"
        self.plugins.mkdir()
        self.env=os.environ.copy()
        self.env.update(PATH=str(self.bin)+":"+self.env["PATH"],ZPLUGINDIR=str(self.plugins),
                        ZSH_PLUGINS_NO_LOAD="1",RECORD=str(self.root/"record"))
        self.target=self.plugins/"zsh-autosuggestions"

    def mock(self,name,code):
        p=self.bin/name
        p.write_text(f"#!{sys.executable}\n"+code)
        p.chmod(0o755)

    def run_zsh(self,code):
        return subprocess.run([ZSH,"-fc",BOOT+code,"--",str(ROOT)],
                              env=self.env,capture_output=True)

    def plugin(self,command):
        result=self.run_zsh('source "$1/zsh/plugins.zsh"; ZSH_PLUGIN_REPOS=(zsh-users/zsh-autosuggestions); '+command)
        return result

    def mock_git(self):
        self.mock("git", """import os,pathlib,sys
target=pathlib.Path(sys.argv[-1])
target.mkdir(parents=True)
(target/'.git').mkdir()
(target/'partial').write_text('download')
pathlib.Path(os.environ['RECORD']).write_text(str(target))
if os.environ.get('FAIL_CLONE'): sys.exit(128)
if not os.environ.get('INCOMPLETE'):
    (target/'zsh-autosuggestions.plugin.zsh').write_text('# downloaded plugin')
""")

    def test_failed_first_install_can_be_retried(self):
        self.mock_git()
        self.env["FAIL_CLONE"]="1"
        result=self.plugin("zplugin-install")
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.target.exists())
        self.assertEqual(list(self.plugins.iterdir()),[])
        del self.env["FAIL_CLONE"]
        result=self.plugin("zplugin-install")
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue((self.target/"zsh-autosuggestions.plugin.zsh").is_file())
        stage=Path((self.root/"record").read_text()).parent
        self.assertFalse(stage.exists())

    def test_incomplete_download_never_activates(self):
        self.mock_git()
        self.env["INCOMPLETE"]="1"
        result=self.plugin("zplugin-install")
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.target.exists())
        self.assertEqual(list(self.plugins.iterdir()),[])

    def test_reinstall_preserves_old_content_until_download_succeeds(self):
        self.mock_git()
        self.target.mkdir()
        (self.target/"private-change").write_text("keep")
        result=self.plugin("zplugin-install")
        self.assertNotEqual(result.returncode,0)
        self.assertIn(b"zplugin-reinstall zsh-autosuggestions",result.stderr)
        self.env["FAIL_CLONE"]="1"
        result=self.plugin("zplugin-reinstall zsh-autosuggestions")
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((self.target/"private-change").read_text(),"keep")
        del self.env["FAIL_CLONE"]
        result=self.plugin("zplugin-reinstall zsh-autosuggestions")
        self.assertEqual(result.returncode,0,result.stderr)
        backup=next(self.plugins.glob(".zsh-autosuggestions.backup-*"))/"plugin"
        self.assertEqual((backup/"private-change").read_text(),"keep")
        self.assertTrue((self.target/"zsh-autosuggestions.plugin.zsh").is_file())

    def test_failed_activation_restores_old_plugin(self):
        self.mock_git()
        real_mv=shutil.which("mv")
        self.mock("mv",f"""import os,subprocess,sys
args=sys.argv[1:]
if '.install-' in args[-2] and args[-2].endswith('/plugin'): sys.exit(1)
sys.exit(subprocess.call([{real_mv!r},*args]))
""")
        self.target.mkdir()
        (self.target/"keep").write_text("old")
        result=self.plugin("zplugin-reinstall zsh-autosuggestions")
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((self.target/"keep").read_text(),"old")
        self.assertFalse(any(self.plugins.glob("*.install-lock")))

    def test_invalid_name_and_active_lock_are_preserved(self):
        self.mock_git()
        result=self.plugin("zplugin-reinstall ../other")
        self.assertEqual(result.returncode,2)
        lock=self.plugins/".zsh-autosuggestions.install-lock"
        lock.mkdir()
        result=self.plugin("zplugin-install")
        self.assertNotEqual(result.returncode,0)
        self.assertTrue(lock.is_dir())
        self.assertFalse((self.root/"record").exists())

    def test_ctrl_f_preserves_multiple_paths_and_cancel(self):
        self.env["PATH"]=str(self.bin)
        names=["a b", "quote'\"$(){}.txt", "中文\nline\n", "-option"]
        self.env["SELECTED"]=json.dumps(names)
        producer="import os,sys,json\nsys.stdout.buffer.write(b''.join(x.encode()+b'\\0' for x in json.loads(os.environ['SELECTED'])))"
        self.mock("fzf", """import json,os,pathlib,sys
if '--zsh' in sys.argv: sys.exit(0)
assert '--read0' in sys.argv and '--print0' in sys.argv and '--multi' in sys.argv
sys.stdin.buffer.read()
if os.environ.get('CANCEL'): sys.exit(130)
sys.stdout.buffer.write(b''.join(x.encode()+b'\\0' for x in json.loads(os.environ['SELECTED'])))
""")
        code=r"""zle() { :; }; source "$1/zsh/fzf.zsh"; LBUFFER='before '; _fzf_file_no_hidden
local result=$?
eval "set -- $LBUFFER"
printf '%s\0' "$@"
return $result"""
        for provider in ("fd","fdfind","find"):
            self.mock(provider,producer)
            result=self.run_zsh(code)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout.split(b"\0")[:-1],[b"before"]+[x.encode() for x in names])
            self.env["CANCEL"]="1"
            result=self.run_zsh(code)
            self.assertEqual(result.returncode,130)
            self.assertEqual(result.stdout,b"before\0")
            del self.env["CANCEL"]
            (self.bin/provider).unlink()
