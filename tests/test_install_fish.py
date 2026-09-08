"""Stable Fish installation: isolated HOME, fixed releases, real archive/checksum tools."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/install-fish.sh"


class FishInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fish-install-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home with spaces"
        self.bin = self.root / "mocks"
        self.bin.mkdir()
        self.entry = self.home / ".local/bin/fish"
        self.entry.parent.mkdir(parents=True)
        self.entry.write_text("original fish")
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), FIXTURE=str(self.root),
                        PATH=str(self.bin) + ":" + self.env["PATH"])
        self.mock("curl", """#!/usr/bin/env python3
import os, pathlib, shutil, sys
args=sys.argv[1:]
url=next(arg for arg in args if arg.startswith('https://'))
root=pathlib.Path(os.environ['FIXTURE'])
if (root/'FAIL_ALL').exists(): sys.exit(22)
if not url.endswith('/latest') and (root/'NO_ARCHIVE').exists(): sys.exit(99)
shutil.copyfile(root/('release.json' if url.endswith('/latest') else 'archive'),args[args.index('-o')+1])
""")

    def mock(self, name, content):
        target = self.bin / name
        target.write_text(content)
        target.chmod(0o755)

    def fixture(self, system="Linux", arch="x86_64", prerelease=False,
                bad_digest=False, broken=False):
        self.mock("uname", '#!/bin/sh\ncase "$1" in -s) echo ' + system +
                  ';; -m) echo ' + arch + ';; esac\n')
        version = "4.9.2"
        suffix = arch if arch != "arm64" else "aarch64"
        asset = f"fish-{version}-linux-{suffix}.tar.xz" if system == "Linux" else f"fish-{version}.app.zip"
        binary = b'#!/bin/sh\nexit 1\n' if broken else b'#!/bin/sh\ncase "$*" in *--version*) echo "fish, version 4.9.2";; esac\n'
        archive = self.root / "archive"
        if system == "Linux":
            with tarfile.open(archive, "w:xz") as tar:
                info = tarfile.TarInfo("fish")
                info.mode = 0o755
                info.size = len(binary)
                tar.addfile(info, io.BytesIO(binary))
        else:
            with zipfile.ZipFile(archive, "w") as z:
                prefix = f"fish-{version}.app/Contents/Resources/base/usr/local"
                for name in ("fish", "fish_indent", "fish_key_reader"):
                    info = zipfile.ZipInfo(f"{prefix}/bin/{name}")
                    info.external_attr = 0o100755 << 16
                    z.writestr(info, binary)
                z.writestr(f"{prefix}/share/fish/man/man1/fish.1", "manual fixture")
        digest = "0"*64 if bad_digest else hashlib.sha256(archive.read_bytes()).hexdigest()
        release = {"tag_name": version, "draft": False, "prerelease": prerelease,
                   "assets": [{"name": asset, "digest": "sha256:"+digest,
                               "browser_download_url": f"https://github.com/fish-shell/fish-shell/releases/download/{version}/{asset}"}]}
        (self.root/"release.json").write_text(json.dumps(release))

    def run_install(self):
        return subprocess.run(["bash",str(SCRIPT)],env=self.env,capture_output=True,text=True)

    def test_platforms_and_version_skip(self):
        for system, arch in (("Linux","x86_64"),("Linux","aarch64"),("Darwin","x86_64"),("Darwin","arm64")):
            with self.subTest(system=system,arch=arch):
                self.fixture(system,arch)
                # Force a fresh installation between platform cases (macOS uses a universal asset).
                if self.entry.is_symlink(): self.entry.unlink()
                first=self.run_install()
                self.assertEqual(first.returncode,0,first.stderr)
                original=self.entry.resolve()
                for name in ("fish","fish_indent","fish_key_reader"):
                    self.assertTrue((self.entry.parent/name).is_file())
                (self.root/"NO_ARCHIVE").touch()
                second=self.run_install()
                self.assertEqual(second.returncode,0,second.stderr)
                self.assertIn("archive download skipped",second.stdout)
                self.assertEqual(self.entry.resolve(),original)
                (self.root/"NO_ARCHIVE").unlink()

    def test_failure_preserves_entries(self):
        for kind in ("prerelease","bad_digest","broken"):
            with self.subTest(kind=kind):
                self.fixture(**{kind:True})
                result=self.run_install()
                self.assertNotEqual(result.returncode,0)
                self.assertEqual(self.entry.read_text(),"original fish")
                self.assertIn("[FAILED]",result.stderr)

    def test_missing_companion_reinstalls(self):
        self.fixture()
        first=self.run_install()
        self.assertEqual(first.returncode,0,first.stderr)
        old=self.entry.resolve()
        (self.entry.parent/"fish_indent").unlink()
        second=self.run_install()
        self.assertEqual(second.returncode,0,second.stderr)
        self.assertNotEqual(self.entry.resolve(),old)

    def test_directory_is_preserved(self):
        self.fixture()
        self.entry.unlink()
        self.entry.mkdir()
        (self.entry/"keep").write_text("keep")
        result=self.run_install()
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((self.entry/"keep").read_text(),"keep")

    def test_download_and_unsupported_architecture(self):
        self.fixture()
        (self.root/"FAIL_ALL").touch()
        self.assertNotEqual(self.run_install().returncode,0)
        (self.root/"FAIL_ALL").unlink()
        self.fixture(arch="riscv64")
        self.assertNotEqual(self.run_install().returncode,0)
        self.assertEqual(self.entry.read_text(),"original fish")
