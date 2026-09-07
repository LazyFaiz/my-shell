"""Run on Linux/macOS: python3 -m unittest discover -s tests -v.
Network and architecture are fixtures; real tar, jq, checksums and Bash run.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/install-neovim.sh'


class NeovimInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='nvim-installer-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home with spaces'
        self.bin = self.root / 'mocks'
        self.bin.mkdir()
        self.entry = self.home / '.local/bin/nvim'
        self.entry.parent.mkdir(parents=True)
        self.entry.write_text('old entry\n')
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), FIXTURE=str(self.root),
                        PATH=str(self.bin) + ':' + self.env['PATH'])
        self.executable('curl', '''#!/usr/bin/env python3
import os, pathlib, shutil, sys
args=sys.argv[1:]
if os.environ.get('DOWNLOAD_FAIL'): sys.exit(22)
url=next(x for x in args if x.startswith('https://'))
if not url.endswith('/latest') and (pathlib.Path(os.environ['FIXTURE'])/'ARCHIVE_FORBIDDEN').exists(): sys.exit(99)
source='release.json' if url.endswith('/latest') else 'archive.tar.gz'
shutil.copyfile(pathlib.Path(os.environ['FIXTURE'])/source,args[args.index('-o')+1])
''')

    def executable(self, name, text):
        file = self.bin / name
        file.write_text(text)
        file.chmod(0o755)

    def fixture(self, system='Linux', machine='x86_64', prerelease=False,
                bad_digest=False, broken_binary=False):
        self.executable('uname', '#!/bin/sh\ncase "$1" in\n-s) echo ' + system +
                        ';;\n-m) echo ' + machine + ';;\nesac\n')
        platform = 'linux' if system == 'Linux' else 'macos'
        arch = 'arm64' if machine in ('aarch64', 'arm64') else 'x86_64'
        name = f'nvim-{platform}-{arch}'
        program = b'#!/bin/sh\nexit 1\n' if broken_binary else b'#!/bin/sh\necho "NVIM v0.12.5"\n'
        archive = self.root / 'archive.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            info = tarfile.TarInfo(name + '/bin/nvim')
            info.mode = 0o755
            info.size = len(program)
            tar.addfile(info, io.BytesIO(program))
        digest = '0' * 64 if bad_digest else hashlib.sha256(archive.read_bytes()).hexdigest()
        release = {'tag_name': 'v0.12.5', 'draft': False, 'prerelease': prerelease,
                   'assets': [{'name': name + '.tar.gz', 'digest': 'sha256:' + digest,
                    'browser_download_url': f'https://github.com/neovim/neovim/releases/download/v0.12.5/{name}.tar.gz'}]}
        (self.root / 'release.json').write_text(json.dumps(release))

    def run_installer(self):
        return subprocess.run(['bash', str(SCRIPT)], env=self.env,
                              capture_output=True, text=True)

    def test_supported_platforms_and_repeat_install(self):
        for system, machine in [('Linux', 'x86_64'), ('Linux', 'aarch64'),
                                ('Darwin', 'x86_64'), ('Darwin', 'arm64')]:
            with self.subTest(system=system, machine=machine):
                self.fixture(system, machine)
                result = self.run_installer()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(self.entry.is_symlink())
                self.assertTrue(self.entry.resolve().is_file())
        backups = list((self.home / '.local/opt').glob('nvim-entry-backup-*/nvim'))
        self.assertEqual(len(backups), 4)
        self.assertTrue(any(p.read_text() == 'old entry\n' for p in backups))

    def test_failure_preserves_original_entry(self):
        for setting in ('prerelease', 'bad_digest', 'broken_binary'):
            with self.subTest(setting=setting):
                self.fixture(**{setting: True})
                result = self.run_installer()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.entry.read_text(), 'old entry\n')
                self.assertFalse(self.entry.is_symlink())

    def test_download_failure(self):
        self.fixture()
        self.env['DOWNLOAD_FAIL'] = '1'
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.entry.read_text(), 'old entry\n')

    def test_unsupported_architecture(self):
        self.fixture(machine='riscv64')
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.entry.read_text(), 'old entry\n')

    def test_directory_entry_is_not_replaced(self):
        self.fixture()
        self.entry.unlink()
        self.entry.mkdir()
        (self.entry / 'keep').write_text('keep')
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual((self.entry / 'keep').read_text(), 'keep')


    def test_same_release_skips_archive_download(self):
        self.fixture()
        first = self.run_installer()
        self.assertEqual(first.returncode, 0, first.stderr)
        original = self.entry.resolve()
        # Metadata remains readable, but any new archive request will fail.
        (self.root / 'ARCHIVE_FORBIDDEN').touch()
        second = self.run_installer()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn('archive download skipped', second.stdout)
        self.assertEqual(self.entry.resolve(), original)

    def test_error_reports_phase(self):
        self.fixture(bad_digest=True)
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('step=checksum', result.stderr)
        self.assertIn('docs/maintenance.md', result.stderr)

if __name__ == '__main__':
    unittest.main()
