"""Run on Linux/macOS: python3 -m unittest discover -s tests -v.
Network and architecture are fixtures; real tar, jq, checksums and Bash run.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import zipfile
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/install-yazi.sh'


class YaziInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='yazi-installer-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home with spaces'
        self.bin = self.root / 'mocks'
        self.bin.mkdir()
        self.entry = self.home / '.local/bin/yazi'
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
source='release.json' if url.endswith('/latest') else 'archive.zip'
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
        platform = 'unknown-linux-musl' if system == 'Linux' else 'apple-darwin'
        arch = 'aarch64' if machine in ('aarch64', 'arm64') else 'x86_64'
        name = f'yazi-{arch}-{platform}'
        program = b'#!/bin/sh\nexit 1\n' if broken_binary else b'#!/bin/sh\necho "ZELLIJ v0.12.5"\n'
        archive = self.root / 'archive.zip'
        with zipfile.ZipFile(archive, 'w') as zip_file:
            for binary in ('yazi', 'ya'):
                info = zipfile.ZipInfo(name + '/' + binary)
                info.external_attr = 0o100755 << 16
                zip_file.writestr(info, program)
        digest = '0' * 64 if bad_digest else hashlib.sha256(archive.read_bytes()).hexdigest()
        release = {'tag_name': 'v0.12.5', 'draft': False, 'prerelease': prerelease,
                   'assets': [{'name': name + '.zip', 'digest': 'sha256:' + digest,
                    'browser_download_url': f'https://github.com/sxyazi/yazi/releases/download/v0.12.5/{name}.zip'}]}
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
                self.assertTrue((self.entry.parent / 'ya').resolve().is_file())
        backups = list((self.home / '.local/opt').glob('yazi-entry-backup-*/yazi'))
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


    def test_main_installer_yazi_option(self):
        self.fixture()
        self.executable('zsh', '#!/bin/sh\nexit 0\n')
        for key in ('XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME'):
            self.env.pop(key, None)
        config = self.home / '.config/zsh'
        config.mkdir(parents=True)
        (config / 'local.zsh').write_text('# preserved\n')
        result = subprocess.run(['bash', str(SCRIPT.with_name('install-config.sh')), '--yazi'],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.entry.is_symlink())
        self.assertTrue((config / '.zshrc').is_file())
        self.assertEqual((config / 'local.zsh').read_text(), '# preserved\n')

if __name__ == '__main__':
    unittest.main()
