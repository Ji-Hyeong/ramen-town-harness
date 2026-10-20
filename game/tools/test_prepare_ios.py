"""Safety checks for staging, not a substitute for Xcode or a real iPhone.

Fake Mach-O fixtures are only used before execution; these tests never launch
an engine, sign an app, touch accounts or inspect the user's save directory.
"""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_qa_app as shared
import prepare_ios as ios
from test_build_qa_app import make_engine, make_project, tree_digest


class IOSPreparationTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.project = make_project(self.root / "project")
        self.godot = make_engine(self.root / "vendor")
        self.template = self.root / "ios.zip"
        self.template.write_bytes(b"not an official template")
        self.output = self.root / "output"

    def prepare(self, **kwargs):
        return ios.prepare(self.godot, self.project, self.template, self.output, **kwargs)

    def test_corruption_refused_before_output_or_source_mutation(self):
        before = tree_digest(self.project)
        with self.assertRaisesRegex(shared.BuildError, "hash mismatch"):
            self.prepare()
        self.assertFalse(self.output.exists())
        self.assertEqual(before, tree_digest(self.project))

    def test_template_symlink_is_refused(self):
        link = self.root / "link.zip"
        link.symlink_to(self.template)
        with self.assertRaisesRegex(shared.BuildError, "regular file"):
            ios.verify_template(link)

    def test_existing_output_is_preserved(self):
        self.output.mkdir()
        (self.output / "keep").write_text("keep this")
        before = tree_digest(self.output)
        with self.assertRaises(shared.BuildError):
            self.prepare()
        self.assertEqual(before, tree_digest(self.output))

    def test_output_cannot_overlap_project(self):
        self.output = self.project / "nested"
        with self.assertRaises(shared.BuildError):
            self.prepare()
        self.assertFalse(self.output.exists())

    def test_missing_signing_team_is_not_fabricated(self):
        # Input hash verification is independently tested above and by the real
        # official archive. Bypass it only to reach this pre-execution guard.
        with patch.object(ios, "verify_template"):
            with self.assertRaisesRegex(shared.BuildError, "real RAMEN_IOS_TEAM_ID"):
                self.prepare(export=True)
        self.assertFalse(self.output.exists())

    def test_invalid_team_is_refused_before_output(self):
        with patch.object(ios, "verify_template"):
            with self.assertRaisesRegex(shared.BuildError, "uppercase"):
                self.prepare(export=True, team='bad\"\nteam')
        self.assertFalse(self.output.exists())

    def test_zero_exit_with_engine_error_is_not_success(self):
        log = self.root / "engine.log"
        log.write_text("SCRIPT ERROR: test error\n")
        with patch.object(shared, "run_logged", return_value=0):
            with self.assertRaisesRegex(shared.BuildError, "despite exit0"):
                ios.checked_run(["not executed"], log, {}, self.root)

    def test_execution_failure_remains_failure(self):
        with patch.object(shared, "run_logged", return_value=1):
            with self.assertRaisesRegex(shared.BuildError, "Command failed"):
                ios.checked_run(["not executed"], self.root / "unused", {}, self.root)

    def test_partial_preparation_failure_keeps_diagnostic_and_sources(self):
        before = tree_digest(self.project)
        with patch.object(ios, "verify_template"), patch.object(shared, "copy_engine", side_effect=shared.BuildError("copy failed")):
            with self.assertRaisesRegex(shared.BuildError, "copy failed"):
                self.prepare()
        self.assertEqual((self.output / "prep/FAILED.txt").read_text(), "copy failed\n")
        self.assertEqual(before, tree_digest(self.project))


if __name__ == "__main__":
    unittest.main()
