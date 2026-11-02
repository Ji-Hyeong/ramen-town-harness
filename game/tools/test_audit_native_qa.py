"""Adversarial mechanical-audit tests; fake fixtures never prove real rendering."""
import contextlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_native_qa as qa


def png(width=16, height=20):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress((b"\0" + b"\x11\x22\x33" * width) * height)) + chunk(b"IEND", b""))


@contextlib.contextmanager
def fixture():
    with tempfile.TemporaryDirectory() as name:
        root = Path(name).resolve()
        app, repo, baseline = (root / part for part in ("app", "repo", "baseline"))
        run = app / "runs/20261102T000000Z-123"
        engine = app / "runtime/Godot.app/Contents/MacOS/Godot"
        files = {app / "prep/project/project.godot": b"[application]\n",
                 app / "prep/project/scripts/a.gd": b"extends Node\n",
                 app / "prep/ramen-qa.pck": b"fake pack", engine: b"fake engine",
                 run / "started.txt": b"started_utc=2026-11-02T00:00:00Z\nlaunch_cwd=/\n",
                 run / "exit-status.txt": b"exit_status=0\nfinished_utc=2026-11-02T00:00:20Z\n",
                 run / "console.log": b"TEST UI checks=12 failures=0 mode=capture\n",
                 run / "godot.log": b"Godot test fixture\n",
                 run / "captures/portrait_case.png": png(),
                 run / "qa-data/portrait/save.json": b'{"schema_version":21,"cash":100}',
                 baseline / "portrait/save.json": b'{"schema_version":21,"cash":100}'}
        repo.mkdir()
        for path, data in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        os.utime(run / "captures/portrait_case.png", (1793577605, 1793577605))
        manifest = {"bundled_files": ["project.godot", "scripts/a.gd"], "pack_sha256": qa.digest(app / "prep/ramen-qa.pck"),
                    "copied_godot": str(engine), "godot_sha256": qa.digest(engine)}
        (app / "prep/build-manifest.json").write_text(json.dumps(manifest))
        spec = {"app_root": str(app), "run_id": run.name, "git_repo": str(repo), "source_revision": "a" * 40,
                "summary_prefix": "TEST UI", "expected_checks": 12, "profiles": {"portrait": [16, 20, 1]},
                "baseline_data": str(baseline), "save_files": ["portrait/save.json"],
                "expected_pack_sha256": manifest["pack_sha256"], "expected_engine_sha256": manifest["godot_sha256"]}
        yield root, run, spec, manifest


def run_fake(spec):
    source = {"project.godot": b"[application]\n", "scripts/a.gd": b"extends Node\n"}
    return qa.audit(spec, source_reader=lambda repo, revision, path: source[path], signature_checker=lambda engine: None)


class NativeAuditTests(unittest.TestCase):
    def rejects(self, mutate):
        with fixture() as (root, run, spec, manifest):
            mutate(root, run, spec, manifest)
            with self.assertRaises((qa.AuditError, OSError, ValueError)):
                run_fake(spec)

    def test_complete_fixture_is_read_only_and_never_claims_visual_acceptance(self):
        with fixture() as (root, run, spec, manifest):
            before = {str(p.relative_to(root)): qa.digest(p) for p in root.rglob("*") if p.is_file()}
            result = run_fake(spec)
            self.assertTrue(result["mechanical_checks_passed"])
            self.assertTrue(result["visual_review_required"])
            self.assertFalse(result["pixel_content_decoded"])
            self.assertFalse(result["iphone_or_human_fun_acceptance"])
            self.assertEqual(len(result["captures"]), 1)
            self.assertEqual(before, {str(p.relative_to(root)): qa.digest(p) for p in root.rglob("*") if p.is_file()})

    def test_zero_exit_diagnostics_and_fake_capture_summaries_are_rejected(self):
        for line in ["ERROR: zero exit", "\x1b[31mSCRIPT ERROR: compile\x1b[0m", "WARNING: leaked node", "FAIL: assertion",
                     "TEST UI checks=12 failures=0 mode=capture", "LAYOUT ONLY: no screenshots", "mode=layout-only"]:
            with self.subTest(line=line):
                self.rejects(lambda root, run, spec, m: (run / "console.log").write_text("TEST UI checks=12 failures=0 mode=capture\n" + line + "\n"))
        for line in ["ERROR: hidden stderr", "\x1b[33mWARNING: hidden warning\x1b[0m"]:
            with self.subTest(engine=line):
                self.rejects(lambda root, run, spec, m: (run / "godot.log").write_text(line + "\n"))

    def test_failed_unfinished_and_inconsistent_run_metadata_are_rejected(self):
        for text in ["exit_status=1\nfinished_utc=2026-11-02T00:00:20Z\n", "exit_status=0\n",
                     "exit_status=0\nfinished_utc=2026-11-01T23:59:59Z\n", "exit_status=0\nexit_status=0\nfinished_utc=2026-11-02T00:00:20Z\n"]:
            with self.subTest(text=text):
                self.rejects(lambda root, run, spec, m: (run / "exit-status.txt").write_text(text))

    def test_missing_extra_stale_corrupt_and_wrong_size_captures_are_rejected(self):
        changes = [lambda p: p.unlink(), lambda p: p.with_name("portrait_extra.png").write_bytes(p.read_bytes()),
                   lambda p: os.utime(p, (0, 0)), lambda p: p.write_bytes(p.read_bytes()[:-1]),
                   lambda p: p.write_bytes(png(17, 20)), lambda p: p.write_bytes(png()[:-12] + b"not an end!!")]
        for index, change in enumerate(changes):
            with self.subTest(case=index):
                self.rejects(lambda root, run, spec, m: change(run / "captures/portrait_case.png"))

    def test_source_pack_engine_and_signature_failures_are_rejected(self):
        for relative in ["prep/project/scripts/a.gd", "prep/ramen-qa.pck", "runtime/Godot.app/Contents/MacOS/Godot"]:
            with self.subTest(path=relative):
                self.rejects(lambda root, run, spec, m: (root / "app" / relative).write_bytes(b"changed"))
        with fixture() as (root, run, spec, manifest):
            def denied(engine):
                raise qa.AuditError("signature failed")
            with self.assertRaisesRegex(qa.AuditError, "signature failed"):
                qa.audit(spec, source_reader=lambda repo, rev, path: (root / "app/prep/project" / path).read_bytes(), signature_checker=denied)

    def test_missing_or_changed_whole_save_is_rejected(self):
        self.rejects(lambda root, run, spec, m: (run / "qa-data/portrait/save.json").unlink())
        self.rejects(lambda root, run, spec, m: (run / "qa-data/portrait/save.json").write_text('{"schema_version":21,"cash":101}'))

    def test_binary_and_manifest_cannot_be_changed_together_to_bypass_pins(self):
        for relative, key in [("prep/ramen-qa.pck", "pack_sha256"), ("runtime/Godot.app/Contents/MacOS/Godot", "godot_sha256")]:
            def coordinated(root, run, spec, manifest):
                path = root / "app" / relative
                path.write_bytes(b"changed binary and manifest")
                manifest[key] = qa.digest(path)
                (root / "app/prep/build-manifest.json").write_text(json.dumps(manifest))
            with self.subTest(path=relative):
                self.rejects(coordinated)

    def test_unpinned_unsafe_or_unknown_specifications_are_rejected(self):
        for key, value in [("source_revision", "HEAD"), ("source_revision", "--help"), ("run_id", "../outside"),
                           ("save_files", ["../outside"]), ("app_root", "relative"), ("expected_checks", 0),
                           ("profiles", {"portrait": [16, 20, True]})]:
            with self.subTest(key=key, value=value):
                self.rejects(lambda root, run, spec, m: spec.update({key: value}))
        self.rejects(lambda root, run, spec, m: spec.update({"unexpected": True}))

    def test_symlinked_capture_is_rejected_even_when_bytes_match(self):
        def link(root, run, spec, manifest):
            path = run / "captures/portrait_case.png"
            outside = root / "outside.png"
            outside.write_bytes(path.read_bytes())
            path.unlink()
            path.symlink_to(outside)
        self.rejects(link)

    def test_existing_or_overlapping_report_is_refused_before_audit(self):
        with fixture() as (root, run, spec, manifest):
            spec_path = root / "spec.json"
            spec_path.write_text(json.dumps(spec))
            existing = root / "existing.json"
            existing.write_text("preserve")
            for target in [existing, spec_path, run / "new.json"]:
                with self.subTest(path=target), self.assertRaises(qa.AuditError):
                    qa.main(["--spec", str(spec_path), "--report", str(target)])
            self.assertEqual(existing.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
