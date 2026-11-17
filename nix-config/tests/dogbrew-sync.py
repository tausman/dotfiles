"""Offline regression tests. Never invoke or modify the real Dogbrew prefix."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = str(Path(sys.argv.pop(1)).resolve())
MOCK = r'''#!/usr/bin/env bash
set -euo pipefail
prefix=${0%/bin/dogbrew}
case "$1" in
  install)
    echo "$2" >> "$prefix/calls"
    [[ ! -e "$prefix/fail-install" ]] || exit 24
    touch "$prefix/$2.installed"
    ;;
  *) echo "Unexpected command: $*" >&2; exit 25 ;;
esac
'''


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.prefix = Path(self.temp.name)
        (self.prefix / "bin").mkdir()
        self.manager = self.prefix / "bin/dogbrew"
        self.manager.write_text(MOCK)
        self.manager.chmod(0o755)

    def run_sync(self, *names):
        return subprocess.run(
            ["bash", SCRIPT, str(self.prefix), *names],
            capture_output=True, text=True, check=False,
        )

    def calls(self):
        path = self.prefix / "calls"
        return path.read_text().splitlines() if path.exists() else []

    def test_missing_bootstrap(self):
        self.manager.unlink()
        result = self.run_sync("workspaces")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Bootstrap", result.stderr)

    def test_install_every_declared_package_on_every_run(self):
        for _ in range(2):
            self.assertEqual(self.run_sync("workspaces", "ddtool").returncode, 0)
        self.assertEqual(self.calls(), ["workspaces", "ddtool", "workspaces", "ddtool"])
        self.assertTrue((self.prefix / "workspaces.installed").exists())
        self.assertTrue((self.prefix / "ddtool.installed").exists())

    def test_undeclared_packages_are_left_alone(self):
        unmanaged = self.prefix / "unmanaged.installed"
        unmanaged.touch()
        self.assertEqual(self.run_sync("workspaces").returncode, 0)
        self.assertEqual(self.calls(), ["workspaces"])
        self.assertTrue(unmanaged.exists())

    def test_install_failure_is_not_swallowed(self):
        (self.prefix / "fail-install").touch()
        self.assertEqual(self.run_sync("workspaces", "ddtool").returncode, 24)
        self.assertEqual(self.calls(), ["workspaces"])

    def test_empty_declaration_does_nothing(self):
        self.assertEqual(self.run_sync().returncode, 0)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
