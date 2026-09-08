"""Actual configuration installers must back up symlink targets, not live links."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
FISH=os.environ.get("FISH_BIN") or shutil.which("fish")


class ConfigBackupTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="config-backup-")
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()
        self.home=self.root/"home"
        self.home.mkdir()
        self.env=os.environ.copy()
        self.env["HOME"]=str(self.home)
        for kind in ("CONFIG","DATA","STATE","CACHE"):
            self.env["XDG_"+kind+"_HOME"]=str(self.home/kind.lower())
        mock=self.root/"bin"
        mock.mkdir()
        zsh=mock/"zsh"
        zsh.write_text("#!/bin/sh\nexit 0\n")
        zsh.chmod(0o755)
        self.env["PATH"]=str(mock)+":"+self.env["PATH"]
        if FISH: self.env["FISH_BIN"]=FISH

    def check_snapshot(self,shell,linked_directory):
        real=self.root/"dotfiles"
        real.mkdir()
        config=Path(self.env["XDG_CONFIG_HOME"])/shell
        config.parent.mkdir(parents=True)
        if linked_directory:
            config.symlink_to(real,target_is_directory=True)
        else:
            config.mkdir()
        module=config/"my-shell" if shell=="fish" else config
        module.mkdir(exist_ok=True)
        source=self.root/"original-module"
        source.write_text("# original module\n")
        target=module/("aliases.fish" if shell=="fish" else "aliases.zsh")
        target.symlink_to(source)
        if shell=="fish":
            (config/"config.fish").write_text("# original entry\n")
        else:
            entry=self.root/"original-zshenv"
            entry.write_text("# original entry\n")
            (self.home/".zshenv").symlink_to(entry)
        script="install-fish-config.sh" if shell=="fish" else "install-config.sh"
        args=["--config-only"] if shell=="fish" else []
        result=subprocess.run(["bash",str(ROOT/"scripts"/script),*args],
                              env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        backups=Path(self.env["XDG_STATE_HOME"])/"my-shell/backups"
        backup=next(backups.iterdir())
        saved=backup/shell/("my-shell/aliases.fish" if shell=="fish" else "aliases.zsh")
        self.assertFalse((backup/shell).is_symlink())
        self.assertFalse(saved.is_symlink())
        self.assertEqual(saved.read_text(),"# original module\n")
        self.assertNotEqual(target.read_text(),saved.read_text())
        source.write_text("# later modification\n")
        self.assertEqual(saved.read_text(),"# original module\n")
        if shell=="zsh":
            self.assertFalse((backup/"zshenv").is_symlink())
            self.assertEqual((backup/"zshenv").read_text(),"# original entry\n")

    def test_zsh_linked_directory(self):
        self.check_snapshot("zsh",True)

    def test_zsh_linked_module(self):
        self.check_snapshot("zsh",False)

    @unittest.skipUnless(FISH,"Fish required")
    def test_fish_linked_directory(self):
        self.check_snapshot("fish",True)

    @unittest.skipUnless(FISH,"Fish required")
    def test_fish_linked_module(self):
        self.check_snapshot("fish",False)

    def test_failed_snapshot_stops_before_overwriting_config(self):
        config=Path(self.env["XDG_CONFIG_HOME"])/"zsh"
        config.mkdir(parents=True)
        (config/"aliases.zsh").write_text("# keep\n")
        (config/"broken").symlink_to(self.root/"missing")
        result=subprocess.run(["bash",str(ROOT/"scripts/install-config.sh")],
                              env=self.env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn("step=backup-config",result.stderr)
        self.assertEqual((config/"aliases.zsh").read_text(),"# keep\n")
