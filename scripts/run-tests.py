#!/usr/bin/env python3
"""Run tests and expose actionable tracebacks in GitHub check annotations."""
import os
from pathlib import Path
import sys
import unittest


class AnnotatedResult(unittest.TextTestResult):
    def report(self, test, err):
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            message = self._exc_info_to_string(err, test)
            message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
            print(f'::error title=Regression test failed::{test.id()}: {message}', flush=True)

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.report(test, err)

    def addError(self, test, err):
        super().addError(test, err)
        self.report(test, err)

    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        if err is not None:
            self.report(subtest, err)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    suite = unittest.defaultTestLoader.discover(str(root / 'tests'))
    result = unittest.TextTestRunner(verbosity=2, resultclass=AnnotatedResult).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
