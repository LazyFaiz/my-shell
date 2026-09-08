"""Exercise actual Fish syntax, startup, quoting and preservation behavior."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
FISH=os.environ.get("FISH_BIN") or shutil.which("fish")


@unittest.skipUnless(FISH, "Fish required")
class FishConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="fish-config-")
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()
        self.home=self.root/"home with spaces"
        self.home.mkdir()
        self.bin=self.root/"mocks"
        self.bin.mkdir()
        self.env=os.environ.copy()
        self.env.update(HOME=str(self.home),TERM="dumb",FISH_BIN=FISH,
                        PATH=str(self.bin)+":"+self.env["PATH"])
        for kind in ("CONFIG","DATA","STATE","CACHE"):
            self.env["XDG_"+kind+"_HOME"]=str(self.home/kind.lower())
        for name in list(self.env):
            if name.startswith("FZF_") or name in ("STARSHIP_CONFIG","MY_SHELL_REPO","MY_SHELL_FISH_DIR"):
                self.env.pop(name,None)
        self.mock("starship", "#!/bin/sh\nexit 0\n")
        self.mock("zoxide", "#!/bin/sh\nexit 0\n")

    def mock(self,name,content):
        file=self.bin/name
        file.write_text(content)
        file.chmod(0o755)

    def fish(self,code,interactive=False):
        return subprocess.run([FISH,"--no-config","-ic" if interactive else "-c",code,
                               "--",str(ROOT)],env=self.env,capture_output=True,text=True)

    def test_noninteractive_is_quiet(self):
        result=self.fish('source "$argv[1]/fish/config.fish"; printf "%s" "$EDITOR"')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stderr,"")
        self.assertTrue(result.stdout in ("vi","nvim") or result.stdout==self.env.get("EDITOR"))
        result=self.fish('source "$argv[1]/fish/config.fish"')
        self.assertEqual(result.stdout,"")
        self.assertEqual(result.stderr,"")

    def test_aliases_hidden_files_and_mkcd(self):
        self.mock("eza", "#!/bin/sh\nprintf '%s\\n' \"$@\"\n")
        self.env["DEST"]=str(self.root/"dir $() ' 中文")
        result=self.fish('source "$argv[1]/fish/aliases.fish"; ll; la; mkcd "$DEST"; printf "PWD=%s" "$PWD"')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.count("-lah"),2)
        self.assertIn("PWD="+self.env["DEST"],result.stdout)

    def test_ls_fallback_and_extract_refuses_existing_directory(self):
        # No eza available: aliases still show hidden files.
        old_path=self.env["PATH"]
        self.env["PATH"]=str(self.bin)
        self.mock("ls", "#!/bin/sh\nprintf '%s\\n' \"$@\"\n")
        result=self.fish('source "$argv[1]/fish/aliases.fish"; ll; la')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.count("-lah"),2)
        self.env["PATH"]=old_path
        import zipfile
        archive=self.root/"archive 中文\nname.zip"
        with zipfile.ZipFile(archive,"w") as z:
            z.writestr("example.txt","content")
        self.env["ARCHIVE"]=str(archive)
        result=self.fish('source "$argv[1]/fish/aliases.fish"; extract "$ARCHIVE"')
        self.assertEqual(result.returncode,0,result.stderr)
        dest=Path(str(archive)+".extracted")
        self.assertEqual((dest/"example.txt").read_text(),"content")
        (dest/"example.txt").write_text("preserve")
        result=self.fish('source "$argv[1]/fish/aliases.fish"; extract "$ARCHIVE"')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((dest/"example.txt").read_text(),"preserve")

    def test_yazi_directory_and_failure(self):
        self.mock("yazi", """#!/usr/bin/env python3
import os,pathlib,sys
target=next(arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--cwd-file='))
pathlib.Path(target).write_text(os.environ['DEST'])
pathlib.Path(os.environ['RECORD']).write_text(target)
sys.exit(int(os.environ.get('YAZI_EXIT','0')))
""")
        dest=self.root/"space ' $() 中文\nend\n"
        dest.mkdir()
        self.env.update(DEST=str(dest),RECORD=str(self.root/"record"))
        code='source "$argv[1]/fish/aliases.fish"; cd "$HOME"; y; set -l rc $status; printf "%s\\0%s" "$PWD" "$rc"'
        result=self.fish(code)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout,str(dest)+"\x000")
        self.assertFalse(Path((self.root/"record").read_text()).exists())
        for target, exitcode in (("",0),(str(dest),7),(str(self.root/"absent"),0)):
            self.env.update(DEST=target,YAZI_EXIT=str(exitcode))
            result=self.fish(code)
            self.assertEqual(result.stdout,str(self.home)+"\x00"+str(exitcode))
            self.assertFalse(Path((self.root/"record").read_text()).exists())

    def test_fzf_bindings_and_preview_special_names(self):
        self.mock("fzf", """#!/bin/sh
if [ "$1" = --fish ]; then
  printf '%s\\n' 'function fzf-file-widget; end' 'function fzf-history-widget; end'
else
  exit 1
fi
""")
        self.mock("bat", """#!/usr/bin/env python3
import json,os,pathlib,sys
pathlib.Path(os.environ['RECORD']).write_text(json.dumps(sys.argv[1:]))
""")
        self.env["RECORD"]=str(self.root/"bat-args")
        code='source "$argv[1]/fish/bindings.fish"; source "$argv[1]/fish/fzf.fish"; printf "%s\\n" "$FZF_CTRL_T_OPTS"; bind -M insert ctrl-t; bind -M insert ctrl-r'
        result=self.fish(code,True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stderr,"")
        self.assertIn("fzf-file-widget",result.stdout)
        self.assertIn("fzf-history-widget",result.stdout)
        # Query the preview without interactive cursor escape sequences.
        options=self.fish('source "$argv[1]/fish/fzf.fish"; printf "%s" "$FZF_CTRL_T_OPTS"').stdout
        preview=shlex.split(options)[1]
        filename="space ' \" $() {} 中文\nfile"
        command=preview.replace("{}",shlex.quote(filename))
        result=self.fish(command)
        self.assertEqual(result.returncode,0,result.stderr)
        args=json.loads((self.root/"bat-args").read_text())
        self.assertEqual(args[-2:],["--",filename])
        self.env["FZF_CTRL_T_OPTS"]="--preview 'custom {}'"
        result=self.fish('source "$argv[1]/fish/fzf.fish"; printf "%s" "$FZF_CTRL_T_OPTS"')
        self.assertEqual(result.stdout,self.env["FZF_CTRL_T_OPTS"])

    def test_old_zoxide_with_embedded_fish_functions(self):
        self.mock("zoxide", """#!/bin/sh
cat <<'FISH'
if not functions -q __zoxide_cd_internal
    source "$__fish_data_dir/functions/cd.fish"
end
function z
    __zoxide_cd_internal $argv
end
FISH
""")
        result=self.fish('source "$argv[1]/fish/prompt.fish"; z "$HOME"; printf "%s" "$PWD"')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stderr,"")
        self.assertEqual(result.stdout,str(self.home))

    def test_config_install_preserves_personal_files_and_zsh(self):
        config=Path(self.env["XDG_CONFIG_HOME"])/"fish"
        (config/"my-shell").mkdir(parents=True)
        (config/"config.fish").write_text("set -g USER_SETTING keep\n")
        (config/"my-shell/local.fish").write_text("set -g LOCAL_SETTING keep\n")
        (config/"fish_variables").write_text("# personal universal variables\n")
        zsh=self.home/".zshenv"
        zsh.write_text("# unchanged\n")
        for _ in range(2):
            result=subprocess.run(["bash",str(ROOT/"scripts/install-fish-config.sh"),"--config-only"],
                                  env=self.env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual((config/"config.fish").read_text().count("# BEGIN my-shell fish"),1)
        self.assertIn("USER_SETTING keep",(config/"config.fish").read_text())
        self.assertIn("LOCAL_SETTING keep",(config/"my-shell/local.fish").read_text())
        self.assertEqual((config/"fish_variables").read_text(),"# personal universal variables\n")
        self.assertEqual(zsh.read_text(),"# unchanged\n")
        self.assertEqual((config/"my-shell/repository").read_text().strip(),str(ROOT))
        backups=list((Path(self.env["XDG_STATE_HOME"])/"my-shell/backups").glob("fish-*/fish/config.fish"))
        self.assertEqual(len(backups),2)
        result=subprocess.run([FISH,"-ic",'printf "%s/%s" "$USER_SETTING" "$LOCAL_SETTING"'],
                              env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stderr,"")
        self.assertIn("keep/keep",result.stdout)

    def test_doctor_multiline_versions_and_old_tealdeer(self):
        self.mock("yazi", "#!/bin/sh\nprintf 'Yazi\\n    Version: 26.9.1 (test)\\n'\n")
        self.mock("tldr", "#!/bin/sh\necho 'tealdeer 1.6.1'\n")
        result=self.fish('set -g MY_SHELL_FISH_DIR "$argv[1]/fish"; source "$argv[1]/fish/maintenance.fish"; shell-doctor')
        self.assertIn("yazi: Yazi 26.9.1",result.stdout)
        self.assertIn("tldr is too old",result.stdout)
        self.assertEqual(result.stderr,"")

    def test_update_wrapper_uses_fish_category(self):
        repo=self.root/"repo with spaces"
        (repo/"scripts").mkdir(parents=True)
        script=repo/"scripts/update.sh"
        script.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
        config=self.root/"config"
        config.mkdir()
        (config/"repository").write_text(str(repo)+"\n")
        self.env["TEST_CONFIG"]=str(config)
        result=self.fish('set -g MY_SHELL_FISH_DIR "$TEST_CONFIG"; source "$argv[1]/fish/maintenance.fish"; shell-update tools fish')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout,"--shell\nfish\ntools\nfish\n")
