"""Maintenance regression tests; use real Zsh for session diagnostics."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ZSH = os.environ.get('ZSH_BIN') or shutil.which('zsh')


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='shell-update-')
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.env=os.environ.copy()
        self.env['HOME']=str(self.root/'home')
        Path(self.env['HOME']).mkdir()
        self.env['GIT_CONFIG_NOSYSTEM']='1'
        self.env['GIT_CONFIG_GLOBAL']=str(self.root/'gitconfig')

    def test_tools_does_not_install_missing_software(self):
        result=subprocess.run(['bash',str(ROOT/'scripts/update.sh'),'tools'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.count('no managed user entry'),3)

    def test_unknown_category_or_tool_rejected(self):
        for args in (['wrong'],['tools','wrong'],['plugins','yazi']):
            result=subprocess.run(['bash',str(ROOT/'scripts/update.sh'),*args],env=self.env,capture_output=True,text=True)
            self.assertEqual(result.returncode,2)

    def test_dirty_repository_is_preserved(self):
        repo=self.root/'repo'
        shutil.copytree(ROOT/'scripts',repo/'scripts')
        subprocess.run(['git','init',str(repo)],env=self.env,check=True,capture_output=True)
        result=subprocess.run(['bash',str(repo/'scripts/update.sh'),'config'],env=self.env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('local changes',result.stderr)
        self.assertTrue((repo/'scripts/update.sh').is_file())

    def test_config_update_fast_forwards_and_runs_installer(self):
        repo=self.root/'repo'
        remote=self.root/'remote.git'
        shutil.copytree(ROOT/'scripts',repo/'scripts')
        # Exercise real Git update while keeping actual user installation out of this test.
        (repo/'scripts/install-config.sh').write_text('#!/bin/bash\nprintf installed > "$HOME/installed"\n')
        for args in (['init',str(repo)], ['-C',str(repo),'config','user.name','Test'],
                     ['-C',str(repo),'config','user.email','test@example.invalid'],
                     ['-C',str(repo),'add','.'], ['-C',str(repo),'commit','-m','fixture'],
                     ['clone','--bare',str(repo),str(remote)],
                     ['-C',str(repo),'remote','add','origin',str(remote)]):
            subprocess.run(['git',*args],env=self.env,check=True,capture_output=True)
        branch=subprocess.check_output(['git','-C',str(repo),'branch','--show-current'],text=True,env=self.env).strip()
        subprocess.run(['git','-C',str(repo),'push','-u','origin',branch],env=self.env,check=True,capture_output=True)
        result=subprocess.run(['bash',str(repo/'scripts/update.sh'),'config'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual((Path(self.env['HOME'])/'installed').read_text(),'installed')


@unittest.skipUnless(ZSH, 'Zsh required')
class DoctorTests(unittest.TestCase):
    def test_live_plugins_and_preview_diagnostics_without_printing_secrets(self):
        with tempfile.TemporaryDirectory(prefix='doctor-') as folder:
            root=Path(folder)
            bin_dir=root/'bin'
            bin_dir.mkdir()
            tool=bin_dir/'uname'
            tool.write_text('#!/bin/sh\necho Linux\n')
            tool.chmod(0o755)
            installed=root/'plugins/zsh-history-substring-search'
            installed.mkdir(parents=True)
            (installed/'zsh-history-substring-search.plugin.zsh').write_text('# installed\n')
            env=os.environ.copy()
            env.update(PATH=str(bin_dir),PRIVATE_TOKEN='never-print-this-secret')
            code='''[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path)
zmodload zsh/parameter || exit 1
source "$1/zsh/maintenance.zsh"
ZSH_CONFIG_DIR="$1/zsh"
ZPLUGINDIR="$2/plugins"
ZSH_LOADED_PLUGINS=(zsh-autosuggestions)
FZF_CTRL_T_OPTS="bad'}"
shell-doctor
'''
            result=subprocess.run([ZSH,'-fc',code,'--',str(ROOT),str(root)],env=env,text=True,capture_output=True)
            self.assertEqual(result.returncode,1,result.stderr)
            self.assertIn('zsh-autosuggestions loaded',result.stdout)
            self.assertIn('installed but not confirmed loaded',result.stdout)
            self.assertIn('zsh-vi-mode missing',result.stdout)
            self.assertIn('Old broken fzf preview',result.stdout)
            self.assertNotIn('never-print-this-secret',result.stdout+result.stderr)

    def test_plugin_update_without_loading_plugins(self):
        with tempfile.TemporaryDirectory(prefix='plugins-') as folder:
            env=os.environ.copy()
            env.update(ZPLUGINDIR=folder,ZSH_PLUGINS_NO_LOAD='1')
            code='''[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path)
zmodload zsh/parameter || exit 1
source "$1/zsh/plugins.zsh"
zplugin-update
'''
            result=subprocess.run([ZSH,'-fc',code,'--',str(ROOT)],env=env,text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('No installed plugins',result.stdout)

    def test_doctor_warns_for_old_neovim(self):
        with tempfile.TemporaryDirectory(prefix='doctor-version-') as folder:
            root=Path(folder)
            nvim=root/'nvim'
            nvim.write_text('#!/bin/sh\necho "NVIM v0.10.4"\n')
            nvim.chmod(0o755)
            env=os.environ.copy()
            env['PATH']=str(root)+':'+env['PATH']
            code='''[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path)
zmodload zsh/parameter || exit 1
source "$1/zsh/maintenance.zsh"
ZSH_CONFIG_DIR="$1/zsh"
ZSH_LOADED_PLUGINS=()
shell-doctor
'''
            result=subprocess.run([ZSH,'-fc',code,'--',str(ROOT)],env=env,capture_output=True,text=True)
            self.assertIn('nvim version is too old',result.stdout)

    def test_update_wrapper_reads_repository_path_with_spaces(self):
        with tempfile.TemporaryDirectory(prefix='repo wrapper ') as folder:
            root=Path(folder)
            (root/'scripts').mkdir()
            (root/'scripts/update.sh').write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n')
            (root/'repository').write_text(str(root)+'\n')
            code='''source "$1/zsh/maintenance.zsh"
ZSH_CONFIG_DIR="$2"
shell-update tools yazi
'''
            result=subprocess.run([ZSH,'-fc',code,'--',str(ROOT),str(root)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout,'tools\nyazi\n')
