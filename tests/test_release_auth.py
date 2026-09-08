"""Metadata authentication must not leak into archive downloads or logs."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


class ReleaseAuthTests(unittest.TestCase):
    def test_authenticated_and_anonymous_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            curl=root/"curl"
            curl.write_text("""#!/usr/bin/env python3
import json,os,pathlib,sys
pathlib.Path(os.environ['RECORD']).write_text(json.dumps(sys.argv[1:]))
print(os.environ.get('HTTP_CODE','200'),end='')
sys.exit(int(os.environ.get('CURL_EXIT','0')))
""")
            curl.chmod(0o755)
            env=os.environ.copy()
            env.update(PATH=str(root)+":"+env["PATH"],RECORD=str(root/"args"))
            for token in ("","test-token-do-not-log"):
                env["GITHUB_TOKEN"]=token
                result=subprocess.run(["bash","-c",
                    'source "$1"; github_latest_release fish-shell/fish-shell "$2"',
                    "--",str(ROOT/"scripts/lib/install-common.sh"),str(root/"release.json")],
                    env=env,capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                args=json.loads((root/"args").read_text())
                self.assertEqual("-H" in args,bool(token))
                self.assertIn("https://api.github.com/repos/fish-shell/fish-shell/releases/latest",args)
                self.assertNotIn("test-token-do-not-log",result.stdout+result.stderr)
            env.update(HTTP_CODE="403",CURL_EXIT="56",GITHUB_ACTIONS="true")
            result=subprocess.run(["bash","-c",
                'source "$1"; github_latest_release fish-shell/fish-shell "$2"',
                "--",str(ROOT/"scripts/lib/install-common.sh"),str(root/"release.json")],
                env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,56)
            self.assertIn("HTTP 403",result.stderr)
            self.assertIn("::error",result.stderr)
            self.assertNotIn("test-token-do-not-log",result.stdout+result.stderr)

    def test_invalid_repository_rejected(self):
        result=subprocess.run(["bash","-c",'source "$1"; github_latest_release https://example.invalid out',
                               "--",str(ROOT/"scripts/lib/install-common.sh")],
                               capture_output=True,text=True)
        self.assertEqual(result.returncode,2)
