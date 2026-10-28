"""build_qa_app.py 의 준비 단계 검증. Godot 와 GUI 는 실행하지 않는다(엔진 호출은 가짜 runner).

가짜 runner 는 준비 로직(경로 거부, 범위, 인자 배열, 진단 보존)만 확인한다. 앱의 그래픽 동작이나
캡처 성공을 보장하지 않는다. 그건 실제 앱 실행 뒤 캡처와 exit-status.txt 로만 확인한다.
실행: python3 -m unittest discover -s game/tools -p 'test_build_qa_app.py' -v
"""
import contextlib
import hashlib
import io
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_qa_app as qa  # noqa: E402

FEATURES = 'config/features=PackedStringArray("4.7", "GL Compatibility")\n'


def tree_digest(root: Path) -> dict:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file() and not p.is_symlink()}


def make_project(root: Path) -> Path:
    files = {
        "project.godot": "[application]\n" + FEATURES,
        "scenes/main.tscn": "[gd_scene]\n",
        "scripts/a.gd": "extends Node\n",
        "scripts/a.gd.uid": "uid://x\n",
        "scripts/.env": "TOKEN=nope\n",
        "assets/fonts/f.ttf": "font",
        "assets/fonts/f.ttf.import": "[remap]\n",
        "assets/credentials.json": "{}",
        "tests/qa_capture.gd": "extends SceneTree\n",
        "docs/shot.png": "png",
        "tools/build_qa_app.py": "# helper",
        "evidence/run.json": "{}",
        "tasks/t.md": "task",
        "AGENTS.md": "agents",
        ".git/config": "[core]",
        ".godot/cache.bin": "cache",
    }
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    return root


def make_engine(root: Path, magic: bytes = bytes.fromhex("cffaedfe")) -> Path:
    app = root / "Godot.app" / "Contents"
    (app / "MacOS").mkdir(parents=True)
    (app / "Resources").mkdir()
    binary = app / "MacOS" / "Godot"
    binary.write_bytes(magic + b"\0" * 32)
    binary.chmod(0o755)
    with open(app / "Info.plist", "wb") as fh:
        plistlib.dump({"CFBundleExecutable": "Godot", "CFBundleIdentifier": "org.godotengine.godot"}, fh)
    return binary


class FakeGodot:
    """Godot 호출을 흉내 내는 runner. 받은 인자와 환경을 기록한다."""

    def __init__(self, fail_step=None, version="4.7.2.stable.official.abc", fixture="tests/qa_capture.gd"):
        self.calls = []
        self.fail_step = fail_step
        self.version = version
        self.fixture = fixture

    def __call__(self, args, **kwargs):
        self.calls.append((list(args), kwargs))
        out = kwargs["stdout"]
        step = "signature" if args[0] == "/usr/bin/codesign" else "version" if "--version" in args else "import" if "--import" in args else "export"
        if step == self.fail_step:
            out.write(f"ERROR: simulated {step} failure\n")
            return subprocess.CompletedProcess(args, 1)
        if step == "version":
            out.write(self.version + "\n")
        elif step == "export":
            # The native fixture extends the original capture harness, so both
            # reviewed entries are retained just as the real exporter does.
            Path(args[-1]).write_bytes(b"GDPC" + b"\0" * 8 + b"tests/qa_capture.gd\0" + self.fixture.encode("utf-8") + b"\0")
        return subprocess.CompletedProcess(args, 0)


class PathAndEngineChecks(unittest.TestCase):
    def test_unsafe_paths_are_rejected(self):
        for raw in ("", "relative/dir", "./x", "/tmp/a/../b", "/tmp/a\nb", "/tmp/a\x00b"):
            with self.assertRaises(qa.BuildError, msg=repr(raw)):
                qa.absolute_path("--output-dir", raw)

    def test_main_rejects_relative_output_without_creating_anything(self):
        with tempfile.TemporaryDirectory() as tmp:
            err = io.StringIO()
            cwd = os.getcwd()
            os.chdir(tmp)
            try:
                with contextlib.redirect_stderr(err):
                    code = qa.main(["--godot", "/x/Godot", "--project", tmp, "--output-dir", "out"])
            finally:
                os.chdir(cwd)
            self.assertEqual(code, 1)
            self.assertIn("절대 경로", err.getvalue())
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_missing_native_runtime_is_a_clear_error_and_creates_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = make_project(root / "game")
            out = root / "out"
            engine = make_engine(root)
            with self.assertRaisesRegex(qa.BuildError, "macOS"):
                qa.prepare(engine, project, out, runner=FakeGodot(), platform="linux")
            plain = root / "godot-plain"
            plain.write_bytes(bytes.fromhex("cffaedfe"))
            plain.chmod(0o755)
            with self.assertRaisesRegex(qa.BuildError, r"\.app"):
                qa.prepare(plain, project, out, runner=FakeGodot(), platform="darwin")
            script_engine_root = root / "script-engine"
            script_engine_root.mkdir()
            with self.assertRaisesRegex(qa.BuildError, "Mach-O"):
                qa.prepare(make_engine(script_engine_root, magic=b"#!/b"), project, out,
                           runner=FakeGodot(), platform="darwin")
            with self.assertRaises(qa.BuildError):
                qa.prepare(root / "nope" / "Godot.app" / "Contents" / "MacOS" / "Godot", project, out,
                           runner=FakeGodot(), platform="darwin")
            self.assertFalse(out.exists())


class OutputDirectoryProtection(unittest.TestCase):
    def test_existing_output_dir_is_refused_and_left_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = make_project(root / "game")
            engine = make_engine(root)
            out = root / "out"
            out.mkdir()
            (out / "user-note.txt").write_text("keep", encoding="utf-8")
            before = tree_digest(root)
            runner = FakeGodot()
            with self.assertRaisesRegex(qa.BuildError, "이미 존재"):
                qa.prepare(engine, project, out, runner=runner, platform="darwin")
            self.assertEqual(runner.calls, [])
            self.assertEqual(tree_digest(root), before)
            self.assertEqual(sorted(p.name for p in out.iterdir()), ["user-note.txt"])

    def test_existing_file_and_dangling_symlink_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = make_project(root / "game")
            engine = make_engine(root)
            as_file = root / "file-out"
            as_file.write_text("x", encoding="utf-8")
            link = root / "link-out"
            link.symlink_to(root / "does-not-exist")
            for target in (as_file, link):
                with self.assertRaisesRegex(qa.BuildError, "이미 존재"):
                    qa.prepare(engine, project, target, runner=FakeGodot(), platform="darwin")
            self.assertEqual(as_file.read_text(encoding="utf-8"), "x")
            self.assertTrue(link.is_symlink())

    def test_output_may_not_overlap_project_or_engine(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = make_project(root / "game")
            make_engine(root)
            for bad in (project / "build", root / "Godot.app" / "Contents" / "out"):
                with self.assertRaisesRegex(qa.BuildError, "겹치거나", msg=str(bad)):
                    qa.check_output_dir(bad, project, root / "Godot.app")


class PreparedBundleScope(unittest.TestCase):
    def prepare(self, root, runner=None):
        project = make_project(root / "game")
        engine = make_engine(root)
        out = root / "out"
        runner = runner or FakeGodot()
        return project, engine, out, runner

    def test_selected_native_fixture_reaches_launcher_and_manifest(self):
        # All reviewed native flows, including culinary identity, must reach
        # the generated launcher/manifest without allowing arbitrary scripts.
        for name in ("bowl_editor_qa.gd", "development_cycle_qa.gd", "food_expression_qa.gd", "first_menu_journey_qa.gd", "foraging_goals_qa.gd", "menu_identity_qa.gd", "foraging_encounters_qa.gd"):
            with self.subTest(fixture=name), tempfile.TemporaryDirectory() as tmp:
                project, engine, out, _ = self.prepare(Path(tmp))
                fixture = "res://tests/" + name
                (project / "tests" / name).write_text("extends SceneTree\n")
                runner = FakeGodot(fixture="tests/" + name)
                result = qa.prepare(engine, project, out, runner=runner, platform="darwin", qa_script=fixture)
                script = (result["app"] / "Contents/MacOS" / qa.LAUNCHER_NAME).read_text()
                self.assertIn(fixture, script)
                self.assertNotIn("--script res://tests/qa_capture.gd", script)
                self.assertEqual(json.loads(result["manifest"].read_text())["qa_script"], fixture)

    def test_unreviewed_or_missing_fixture_creates_no_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, engine, out, runner = self.prepare(Path(tmp))
            for fixture in ("res://tests/other.gd", "res://tests/../../script.gd", "res://tests/bowl_editor_qa.gd"):
                before = tree_digest(Path(tmp))
                with self.assertRaises(qa.BuildError):
                    qa.prepare(engine, project, out, runner=runner, platform="darwin", qa_script=fixture)
                self.assertFalse(out.exists())
                self.assertEqual(runner.calls, [])
                self.assertEqual(tree_digest(Path(tmp)), before)

    def test_missing_exported_fixture_is_rejected_with_diagnostics(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, engine, out, runner = self.prepare(Path(tmp))
            (project / "tests/bowl_editor_qa.gd").write_text("extends SceneTree\n")
            with self.assertRaisesRegex(qa.BuildError, "not exported"):
                qa.prepare(engine, project, out, runner=runner, platform="darwin", qa_script="res://tests/bowl_editor_qa.gd")
            self.assertTrue((out / "prep/FAILED.txt").is_file())
            self.assertFalse((out / qa.APP_NAME).exists())

    def test_snapshot_contains_only_runtime_files_and_source_is_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            before = tree_digest(project)
            result = qa.prepare(engine, project, out, runner=runner, platform="darwin")
            self.assertEqual(tree_digest(project), before)
            snap = out / "prep" / "project"
            got = sorted(p.relative_to(snap).as_posix() for p in snap.rglob("*") if p.is_file())
            self.assertEqual(got, sorted([
                "project.godot", "export_presets.cfg", "scenes/main.tscn", "scripts/a.gd", "scripts/a.gd.uid",
                "assets/fonts/f.ttf", "assets/fonts/f.ttf.import", "tests/qa_capture.gd"]))
            self.assertTrue(result["app"].is_dir())

    def test_engine_calls_use_private_portable_copy_and_never_override_home(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            source_before = tree_digest(root / "Godot.app")
            qa.prepare(engine, project, out, runner=runner, platform="darwin")
            self.assertEqual(len(runner.calls), 3)
            copied = out / qa.RUNTIME_DIR / "Godot.app" / "Contents" / "MacOS" / "Godot"
            for args, kwargs in runner.calls:
                self.assertIsInstance(args, list)
                self.assertFalse(kwargs["shell"])
                self.assertEqual(args[0], str(copied))
                self.assertNotEqual(args[0], str(engine))
                env = kwargs["env"]
                self.assertEqual(env.get("HOME"), os.environ.get("HOME"))
                self.assertNotIn("CODEX_HOME", env)
                self.assertNotIn("home", env)
                for key in ("TMPDIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
                    self.assertTrue(env[key].startswith(str(out / "prep")), key)
                self.assertTrue(all(isinstance(a, str) for a in args))
            # 포터블 마커는 복사본 .app 바로 옆에만 있고, 원본 엔진 번들과 그 옆에는 아무것도 생기지 않는다.
            self.assertTrue((out / qa.RUNTIME_DIR / qa.PORTABLE_MARKER).is_file())
            self.assertFalse((root / qa.PORTABLE_MARKER).exists())
            self.assertEqual(tree_digest(root / "Godot.app"), source_before)
            export_args = runner.calls[2][0]
            self.assertEqual(export_args[-2], qa.PRESET_NAME)
            self.assertIn(str(out / "prep" / "project"), export_args)
            self.assertNotIn(str(project), export_args)

    def test_zero_exit_engine_errors_never_produce_a_ready_app(self):
        class BrokenGodot(FakeGodot):
            def __init__(self, broken_step):
                super().__init__()
                self.broken_step = broken_step

            def __call__(self, args, **kwargs):
                result = super().__call__(args, **kwargs)
                matches = "--import" in args if self.broken_step == "import" else "--export-pack" in args
                if matches:
                    kwargs["stdout"].write("SCRIPT ERROR: Parse Error: simulated zero-exit failure\n")
                return result

        for step in ("import", "export"):
            with self.subTest(step=step), tempfile.TemporaryDirectory() as tmp:
                project, engine, out, _ = self.prepare(Path(tmp))
                with self.assertRaisesRegex(qa.BuildError, "Godot 오류"):
                    qa.prepare(engine, project, out, runner=BrokenGodot(step), platform="darwin")
                self.assertTrue((out / "prep" / "FAILED.txt").is_file())
                self.assertFalse((out / qa.APP_NAME).exists())

    def test_app_layout_and_launcher_are_a_real_copy_not_a_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            app = qa.prepare(engine, project, out, runner=runner, platform="darwin")["app"]
            self.assertEqual(app, out / "Ramen QA.app")
            copied = out / qa.RUNTIME_DIR / "Godot.app" / "Contents" / "MacOS" / "Godot"
            self.assertTrue(copied.is_file())
            self.assertEqual(copied.read_bytes(), engine.read_bytes())
            self.assertEqual((copied.parent.parent / "Info.plist").read_bytes(), (engine.parent.parent / "Info.plist").read_bytes())
            self.assertTrue((app / "Contents" / "Resources" / qa.PACK_NAME).is_file())
            launcher = app / "Contents" / "MacOS" / qa.LAUNCHER_NAME
            self.assertTrue(os.access(launcher, os.X_OK))
            with open(app / "Contents" / "Info.plist", "rb") as fh:
                info = plistlib.load(fh)
            self.assertEqual(info["CFBundleExecutable"], qa.LAUNCHER_NAME)
            # 원본 엔진 번들의 plist 는 그대로다.
            with open(root / "Godot.app" / "Contents" / "Info.plist", "rb") as fh:
                self.assertEqual(plistlib.load(fh)["CFBundleExecutable"], "Godot")
            script = launcher.read_text(encoding="utf-8")
            self.assertNotIn("--headless", script)
            self.assertNotIn("eval", script)
            self.assertNotIn(str(project), script)
            self.assertNotIn("HOME", script)
            self.assertIn(str(copied), script)
            self.assertTrue((out / "prep" / "build-manifest.json").is_file())

    def test_copy_preserves_vendor_metadata_and_excludes_only_local_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            (engine.parent / qa.PORTABLE_MARKER).touch()
            original = tree_digest(root / "Godot.app")
            qa.prepare(engine, project, out, runner=runner, platform="darwin")
            runtime = out / qa.RUNTIME_DIR / "Godot.app"
            self.assertEqual(tree_digest(root / "Godot.app"), original)
            self.assertFalse((runtime / "Contents" / "MacOS" / qa.PORTABLE_MARKER).exists())
            self.assertEqual((runtime / "Contents" / "Info.plist").read_bytes(), (engine.parent.parent / "Info.plist").read_bytes())

    @unittest.skipUnless(sys.platform == "darwin", "macOS extended attributes")
    def test_finder_display_metadata_only_removed_on_copy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            source = root / "Godot.app"
            # 서명 검사에서 거부하는 Finder 표시 정보와 보존할 다른 속성을 함께 준비한다.
            subprocess.run(["/usr/bin/xattr", "-wx", "com.apple.FinderInfo", "01" + "00" * 31, str(source)], check=True)
            subprocess.run(["/usr/bin/xattr", "-w", "local.ramen.test", "keep", str(source)], check=True)
            original = tree_digest(source)
            qa.prepare(engine, project, out, runner=runner, platform="darwin")
            names = lambda p: subprocess.run(["/usr/bin/xattr", str(p)], capture_output=True, text=True, check=True).stdout.splitlines()
            self.assertIn("com.apple.FinderInfo", names(source))
            self.assertNotIn("com.apple.FinderInfo", names(out / qa.RUNTIME_DIR / "Godot.app"))
            self.assertIn("local.ramen.test", names(out / qa.RUNTIME_DIR / "Godot.app"))
            self.assertEqual(tree_digest(source), original)

    def test_signed_engine_is_verified_before_any_execution_and_failure_stops(self):
        for fail in (None, "signature"):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                project, engine, out, runner = self.prepare(root, FakeGodot(fail_step=fail))
                (engine.parent.parent / "_CodeSignature").mkdir()
                if fail:
                    with self.assertRaisesRegex(qa.BuildError, "서명 검증"):
                        qa.prepare(engine, project, out, runner=runner, platform="darwin")
                    self.assertEqual(len(runner.calls), 1)
                    self.assertFalse((out / qa.APP_NAME).exists())
                else:
                    qa.prepare(engine, project, out, runner=runner, platform="darwin")
                    meta = json.loads((out / "prep" / "build-manifest.json").read_text())
                    self.assertTrue(meta["vendor_signature_verified"])
                self.assertEqual(runner.calls[0][0][0], "/usr/bin/codesign")

    def test_failed_step_keeps_diagnostics_and_builds_no_app(self):
        for step in ("version", "import", "export"):
            with self.subTest(step=step), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                project, engine, out, runner = self.prepare(root, FakeGodot(fail_step=step))
                with self.assertRaisesRegex(qa.BuildError, "진단 보존"):
                    qa.prepare(engine, project, out, runner=runner, platform="darwin")
                self.assertTrue((out / "prep" / "FAILED.txt").is_file())
                self.assertIn(f"simulated {step} failure", (out / "prep" / f"{'godot-version' if step == 'version' else step}.log").read_text(encoding="utf-8"))
                self.assertFalse((out / qa.APP_NAME / "Contents" / "MacOS" / qa.LAUNCHER_NAME).exists())

    def test_diagnostic_write_failure_is_reported_explicitly(self):
        class BlockDiagnostic(FakeGodot):
            def __call__(self, args, **kwargs):
                # FAILED.txt 자리를 폴더로 막아 진단 기록이 실패하게 한다.
                (Path(kwargs["cwd"]) / "FAILED.txt").mkdir()
                return super().__call__(args, **kwargs)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, _ = self.prepare(root)
            with self.assertRaises(qa.BuildError) as ctx:
                qa.prepare(engine, project, out, runner=BlockDiagnostic(fail_step="version"), platform="darwin")
            self.assertIn("진단 기록 실패", str(ctx.exception))
            self.assertIn("FAILED.txt", str(ctx.exception))
            self.assertIn("--version", str(ctx.exception))  # 원래 실패 원인도 함께 남는다.

    def test_engine_version_mismatch_and_bad_pack_are_failures(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, _ = self.prepare(root)
            with self.assertRaisesRegex(qa.BuildError, "버전"):
                qa.prepare(engine, project, out, runner=FakeGodot(version="4.3.1.stable"), platform="darwin")
            self.assertFalse((out / qa.APP_NAME / "Contents" / "MacOS" / qa.LAUNCHER_NAME).exists())
        with tempfile.TemporaryDirectory() as tmp:
            pack = Path(tmp) / "x.pck"
            pack.write_bytes(b"GDPC" + b"tests/qa_capture.gd" + b"docs AGENTS.md")
            with self.assertRaisesRegex(qa.BuildError, "AGENTS"):
                qa.verify_pack(pack)
            pack.write_bytes(b"GDPC" + b"scripts/a.gd")
            with self.assertRaisesRegex(qa.BuildError, "qa_capture"):
                qa.verify_pack(pack)

    def test_symlink_inside_project_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            (project / "scripts" / "link.gd").symlink_to(root / "game" / "scripts" / "a.gd")
            with self.assertRaisesRegex(qa.BuildError, "심볼릭"):
                qa.prepare(engine, project, out, runner=runner, platform="darwin")
            self.assertTrue((out / "prep" / "FAILED.txt").is_file())

    def test_symlink_project_json_or_root_is_refused_before_anything_is_created(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            real = root / "real-project.godot"
            real.write_text("[application]\n" + FEATURES, encoding="utf-8")
            (project / "project.godot").unlink()
            (project / "project.godot").symlink_to(real)
            with self.assertRaisesRegex(qa.BuildError, "project.godot"):
                qa.prepare(engine, project, out, runner=runner, platform="darwin")
            self.assertFalse(out.exists())
            self.assertEqual(runner.calls, [])
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project, engine, out, runner = self.prepare(root)
            link = root / "game-link"
            link.symlink_to(project)
            with self.assertRaisesRegex(qa.BuildError, "심볼릭"):
                qa.prepare(engine, link, out, runner=runner, platform="darwin")
            self.assertFalse(out.exists())
            self.assertEqual(runner.calls, [])


class LauncherBehavior(unittest.TestCase):
    """생성된 런처를 가짜 엔진(셸 스크립트)으로 실제 /bin/sh 에서 실행한다. 렌더링은 검증하지 않는다."""

    def run_launcher(self, root, hostile, exit_code):
        out = root / hostile
        (out / "runs").mkdir(parents=True)
        engine = out / "fake engine"
        engine.write_text('#!/bin/sh\nfor a in "$@"; do printf "%s\\n" "$a"; done > "$FAKE_ARGS_FILE"\n'
                          '[ -z "$FAKE_CWD_FILE" ] || pwd -P > "$FAKE_CWD_FILE"\n'
                          'exit "${FAKE_EXIT:-0}"\n', encoding="utf-8")
        engine.chmod(0o755)
        pack = out / "pack file.pck"
        pack.write_bytes(b"GDPC")
        launcher = out / "launcher.sh"
        launcher.write_text(qa.launcher_script(out, engine, pack), encoding="utf-8")
        args_file = root / f"args-{exit_code}.txt"
        env = {"PATH": "/usr/bin:/bin", "FAKE_ARGS_FILE": str(args_file), "FAKE_EXIT": str(exit_code),
               "FAKE_CWD_FILE": str(root / f"cwd-{exit_code}.txt")}
        # 호출 작업 폴더는 일부러 '/' 가 아닌 root 로 두어 런처가 직접 '/' 로 옮기는지 확인한다.
        proc = subprocess.run(["/bin/sh", str(launcher)], cwd=str(root), env=env, capture_output=True, text=True, timeout=60)
        return out, args_file, proc

    def test_hostile_path_is_inert_arguments_are_exact_and_status_is_recorded(self):
        hostile = "o ut'q\"$(touch PWNED_MARK)`touch PWNED_MARK2` ;&"
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out, args_file, proc = self.run_launcher(root, hostile, 3)
            self.assertEqual(proc.returncode, 3, proc.stderr)
            self.assertFalse(any(p.name in ("PWNED_MARK", "PWNED_MARK2") for p in root.rglob("*")))
            run = Path((out / "latest-run.txt").read_text(encoding="utf-8").strip())
            self.assertEqual(run.parent, out / "runs")
            args = args_file.read_text(encoding="utf-8").splitlines()
            self.assertEqual(args[:2], ["--main-pack", str(out / "pack file.pck")])
            self.assertIn("--script", args)
            self.assertEqual(args[args.index("--script") + 1], "res://tests/qa_capture.gd")
            self.assertNotIn("--headless", args)
            self.assertNotIn("--layout-only", args)
            self.assertIn(f"--qa-out={run}/captures", args)
            self.assertIn(f"--dev-data-dir={run}/qa-data", args)
            self.assertIn("exit_status=3", (run / "exit-status.txt").read_text(encoding="utf-8"))
            self.assertTrue((run / "started.txt").is_file())
            # 가짜 엔진이 실제로 본 작업 폴더가 '/' 이고 진단에도 기록된다. '/' 아래에는 아무것도 만들지 않는다.
            self.assertEqual((root / "cwd-3.txt").read_text(encoding="utf-8").strip(), "/")
            self.assertIn("launch_cwd=/\n", (run / "started.txt").read_text(encoding="utf-8"))
            self.assertEqual(sorted(p.name for p in run.iterdir()),
                             ["captures", "console.log", "exit-status.txt", "qa-data", "started.txt", "tmp"])

    def test_each_launch_gets_a_fresh_run_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out, _, first = self.run_launcher(root, "o", 0)
            run1 = (out / "latest-run.txt").read_text(encoding="utf-8").strip()
            self.assertEqual(first.returncode, 0, first.stderr)
            env = {"PATH": "/usr/bin:/bin", "FAKE_ARGS_FILE": str(root / "again.txt")}
            subprocess.run(["/bin/sh", str(out / "launcher.sh")], cwd=str(root), env=env, check=True, timeout=60)
            run2 = (out / "latest-run.txt").read_text(encoding="utf-8").strip()
            self.assertNotEqual(run1, run2)
            self.assertEqual(len(list((out / "runs").iterdir())), 2)

    def test_missing_pack_fails_loudly_instead_of_running(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out, args_file, _ = self.run_launcher(root, "o", 0)
            (out / "pack file.pck").unlink()
            before = len(list((out / "runs").iterdir()))
            proc = subprocess.run(["/bin/sh", str(out / "launcher.sh")], cwd=str(root), env={"PATH": "/usr/bin:/bin"}, timeout=60)
            self.assertEqual(proc.returncode, 72)
            self.assertEqual(len(list((out / "runs").iterdir())), before)
            self.assertIn("pack missing", (out / "launcher-errors.log").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
