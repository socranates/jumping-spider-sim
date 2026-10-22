"""Runner infrastructure regressions: python -m unittest discover -s tests -p test_runner.py"""
import importlib.util
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("windowsill_runner", pathlib.Path(__file__).with_name("run.py"))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def invoke(self, args, code=0):
        with patch.object(sys, "argv", ["run.py", "test-luau", *args]), patch.object(runner, "bundle", return_value="-- fixture"), patch.object(runner.subprocess, "call", return_value=code) as call:
            with self.assertRaises(SystemExit) as result:
                runner.main()
            return result.exception.code, call

    def test_missing_default_is_failure(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(runner, "HERE", pathlib.Path(directory)):
            status, call = self.invoke([])
            self.assertEqual(status, 1)
            call.assert_not_called()

    def test_missing_named_is_failure(self):
        status, call = self.invoke(["does-not-exist.luau"])
        self.assertEqual(status, 1)
        call.assert_not_called()

    def test_exit_failure_propagates_and_bundle_is_removed(self):
        status, call = self.invoke(["state.luau"], 1)
        self.assertEqual(status, 1)
        self.assertFalse(pathlib.Path(call.call_args.args[0][1]).exists())

    def test_pass_removes_bundle(self):
        status, call = self.invoke(["state.luau"])
        self.assertEqual(status, 0)
        self.assertFalse(pathlib.Path(call.call_args.args[0][1]).exists())

    def test_missing_module_is_failure(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(runner, "SRC", pathlib.Path(directory)):
            with self.assertRaises(FileNotFoundError):
                runner.bundle("state.luau")


if __name__ == "__main__":
    unittest.main()
