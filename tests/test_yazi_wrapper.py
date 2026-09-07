"""Test the y wrapper with real Zsh and a fake Yazi process."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ZSH = os.environ.get('ZSH_BIN') or shutil.which('zsh')
ALIASES = Path(__file__).resolve().parents[1] / 'zsh/aliases.zsh'


@unittest.skipUnless(ZSH, 'Zsh required')
class YaziWrapperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='yazi-wrapper-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.cwd = self.root / "space 'quote' $dollar\nnewline"
        self.cwd.mkdir()
        self.tempfiles = self.root / 'tmp'
        self.tempfiles.mkdir()
        executable = self.bin / 'yazi'
        executable.write_text(f'#!{sys.executable}\n' + '''import os,sys
path=next(arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--cwd-file='))
with open(path, 'w') as file: file.write(os.environ.get('YAZI_CWD', ''))
sys.exit(int(os.environ.get('YAZI_EXIT', '0')))
''')
        executable.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin)+':'+self.env['PATH'],
                        TMPDIR=str(self.tempfiles), YAZI_CWD=str(self.cwd))

    def run_wrapper(self):
        code = '''[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path)
zmodload zsh/parameter || exit 1
compdef() { :; }
source "$1"
y
result=$?
print -r -- "$PWD"
exit "$result"
'''
        result = subprocess.run([ZSH, '-fc', code, '--', str(ALIASES)],
                                env=self.env, cwd=self.root, capture_output=True, text=True)
        self.assertEqual(list(self.tempfiles.iterdir()), [])
        return result

    def test_follow_special_directory(self):
        result=self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, str(self.cwd)+'\n')

    def test_empty_cwd_preserves_directory(self):
        self.env['YAZI_CWD']=''
        result=self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, str(self.root)+'\n')

    def test_error_preserves_directory_and_exit_code(self):
        self.env['YAZI_EXIT']='7'
        result=self.run_wrapper()
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(result.stdout, str(self.root)+'\n')

    def test_nonexistent_directory_is_ignored(self):
        self.env['YAZI_CWD']=str(self.root/'missing')
        result=self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, str(self.root)+'\n')
