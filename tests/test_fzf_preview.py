"""Regression tests: ZSH_BIN=/path/to/zsh python3 -B -m unittest discover -s tests -v."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

CONFIG = Path(__file__).resolve().parents[1] / 'zsh/fzf.zsh'
ZSH = os.environ.get('ZSH_BIN') or shutil.which('zsh')


@unittest.skipUnless(ZSH, 'Zsh is required for preview regression tests')
class FzfPreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='fzf-preview-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fzf = self.bin / 'fzf'
        fzf.write_text('#!/bin/sh\nexit 0\n')
        fzf.chmod(0o755)
        self.env = os.environ.copy()
        self.env.pop('FZF_CTRL_T_OPTS', None)
        self.env['PATH'] = str(self.bin)

    def preview_tool(self, name):
        tool = self.bin / name
        tool.write_text(f'#!{sys.executable}\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
        tool.chmod(0o755)

    def options(self, repeat=False):
        # Only the preview is tested; widget registration is unrelated.
        code = '[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path); zmodload zsh/parameter || exit 1; zle() { :; }; source "$1"; '
        if repeat:
            code += 'source "$1"; '
        code += 'print -rn -- "${FZF_CTRL_T_OPTS-}"'
        return subprocess.check_output([ZSH, '-fc', code, '--', str(CONFIG)],
                                       env=self.env, text=True)

    def test_default_bat_preview_handles_special_filenames(self):
        self.preview_tool('bat')
        options = self.options(repeat=True)
        self.assertEqual(options, "--preview 'bat --color=always --style=numbers --line-range=:300 -- {}'")
        args = shlex.split(options)
        file = str(self.root / "file with 'quote' and $dollar.txt")
        # fzf replaces {} with a shell-quoted filename before invoking the shell.
        command = args[1].replace('{}', shlex.quote(file))
        actual = subprocess.check_output([ZSH, '-fc', command], env=self.env, text=True)
        self.assertEqual(json.loads(actual)[-2:], ['--', file])

    def test_batcat_fallback(self):
        self.preview_tool('batcat')
        self.assertEqual(self.options(), "--preview 'batcat --color=always --style=numbers --line-range=:300 -- {}'")

    def test_custom_options_preserved_across_reloads(self):
        self.preview_tool('bat')
        custom = "--preview 'head -- {}' --preview-window=down"
        self.env['FZF_CTRL_T_OPTS'] = custom
        self.assertEqual(self.options(repeat=True), custom)

    def test_missing_preview_tool(self):
        self.assertEqual(self.options(), '')


if __name__ == '__main__':
    unittest.main()
