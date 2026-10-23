#!/usr/bin/env python3
"""자체 포함 로컬 QA 앱(Ramen QA.app)을 만든다. 개발용이며 서명/배포/iOS 빌드가 아니다.

순서: 경로·엔진 검증(부작용 없음) → output-dir 생성 → 허용 목록만 담은 프로젝트 스냅샷 →
서명을 유지한 엔진 복사 → 헤드리스 import → --export-pack → PCK 확인 → 별도 QA 런처 앱 조립.
원본 프로젝트와 원본 엔진 번들은 건드리지 않는다. HOME 은 바꾸지 않는다. 대신 검증한 엔진 번들을 output-dir 로
복사하고 그 옆에 Godot 포터블 마커(_sc_)를 만들어, 복사본으로 준비(import/export)와 실행을 모두 해서 editor_data 가 output-dir 안에 생기게 한다.
이미 있는 output-dir 은 덮어쓰거나 지우지 않고 거부한다. 준비 실패 시 output-dir/prep 의 로그와 FAILED.txt 를 남긴다.
앱을 실행하는 일은 이 스크립트가 하지 않는다. 표준 라이브러리만 사용하고 셸을 거치지 않는다(인자 배열).

생성된 앱을 실행하면 런처가 runs/<UTC시각>-<pid>/ 를 새로 만들고 실제 렌더러로 선택한 검토용 fixture 를 돌린 뒤
captures/, qa-data/, godot.log, console.log, exit-status.txt 를 그 안에 남긴다. 준비 성공은 그래픽 성공이 아니다.
런처는 엔진을 작업 폴더 '/' 에서 실행하고(started.txt 의 launch_cwd 에 기록) 모든 경로는 output-dir 안의 절대 경로를 쓴다.
"""
import argparse
import hashlib
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from fnmatch import fnmatch
from pathlib import Path

APP_NAME = "Ramen QA.app"
RUNTIME_DIR = "runtime"
PRESET_NAME = "Ramen QA Pack"
LAUNCHER_NAME = "ramen-qa-launcher"
PACK_NAME = "ramen-qa.pck"
QA_SCRIPT = "res://tests/qa_capture.gd"
# 스냅샷에 넣는 것은 project.godot 과 아래 폴더뿐이다(docs, tools, evidence, .git, tasks 등은 들어가지 않는다).
ALLOWED_DIRS = ("scenes", "scripts", "assets", "tests")
REQUIRED_FILES = ("project.godot", "scenes/main.tscn", "tests/qa_capture.gd")
# 허용 폴더 안이라도 자격 증명처럼 보이는 파일은 건너뛰고 manifest 에 기록한다.
SECRET_PATTERNS = (".env*", "*.pem", "*.key", "*.p12", "*.pfx", "*.jks", "*.keystore", "id_rsa*",
                   "id_ed25519*", "*credential*", "*secret*", "*.token", "auth*.json")
FORBIDDEN_IN_PACK = (b"build_qa_app", b"build_local_apps", b"AGENTS.md", b"VERIFICATION.md")
MACHO_MAGICS = {bytes.fromhex(h) for h in (
    "feedface", "feedfacf", "cefaedfe", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
STEP_TIMEOUT = 900
PORTABLE_MARKER = "_sc_"  # Godot 가 .app 옆에서 찾는 자체 포함(포터블) 설정 마커


class BuildError(Exception):
    pass


def absolute_path(label: str, raw: str) -> Path:
    """절대 경로이고 제어문자/'..' 가 없는 경로만 허용한다."""
    if not raw or not os.path.isabs(raw):
        raise BuildError(f"{label}: 절대 경로여야 합니다: {raw!r}")
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in raw):
        raise BuildError(f"{label}: 제어문자가 있는 경로는 쓸 수 없습니다.")
    if ".." in Path(raw).parts:
        raise BuildError(f"{label}: '..' 를 포함할 수 없습니다: {raw}")
    return Path(os.path.normpath(raw))


def is_within(path: Path, root: Path) -> bool:
    a = os.path.realpath(path)
    b = os.path.realpath(root)
    return os.path.commonpath([a, b]) == b


def verify_engine(godot: Path, platform: str) -> Path:
    """<이름>.app/Contents/MacOS/<실행 파일> 형태의 실제 macOS 엔진인지 확인하고 .app 경로를 돌려준다."""
    if platform != "darwin":
        raise BuildError(f"네이티브 macOS 런타임이 필요합니다(현재 플랫폼: {platform}). QA 앱을 만들지 않습니다.")
    if godot.is_symlink() or not godot.is_file() or not os.access(godot, os.X_OK):
        raise BuildError(f"--godot: 심볼릭 링크가 아닌 실행 가능한 파일이어야 합니다: {godot}")
    macos_dir = godot.parent
    app = macos_dir.parent.parent
    if macos_dir.name != "MacOS" or macos_dir.parent.name != "Contents" or app.suffix != ".app":
        raise BuildError(f"--godot: <이름>.app/Contents/MacOS/<실행 파일> 형태의 macOS 앱 번들 안 바이너리가 필요합니다: {godot}")
    try:
        with open(macos_dir.parent / "Info.plist", "rb") as fh:
            info = plistlib.load(fh)
    except (OSError, plistlib.InvalidFileException, ValueError) as err:
        raise BuildError(f"--godot: 번들 Info.plist 를 읽을 수 없습니다: {err}")
    if info.get("CFBundleExecutable") != godot.name:
        raise BuildError(f"--godot: Info.plist 의 CFBundleExecutable 이 {godot.name!r} 이 아닙니다: {info.get('CFBundleExecutable')!r}")
    with open(godot, "rb") as fh:
        if fh.read(4) not in MACHO_MAGICS:
            raise BuildError(f"--godot: Mach-O 실행 파일이 아닙니다: {godot}")
    return app


def check_project_source(project: Path) -> None:
    """프로젝트 루트와 project.godot 가 심볼릭 링크면 내용을 복사/읽기 전에 거부한다."""
    if project.is_symlink():
        raise BuildError(f"--project: 심볼릭 링크 폴더는 쓸 수 없습니다: {project}")
    if not project.is_dir():
        raise BuildError(f"--project: 폴더가 아닙니다: {project}")
    manifest = project / "project.godot"
    if manifest.is_symlink():
        raise BuildError(f"--project: project.godot 가 심볼릭 링크입니다: {manifest}")


def project_engine_series(project: Path) -> str:
    """project.godot 의 config/features 첫 항목("4.7" 같은 major.minor)을 읽는다."""
    check_project_source(project)
    for rel in REQUIRED_FILES:
        if not (project / rel).is_file():
            raise BuildError(f"--project: 필요한 파일이 없습니다: {project / rel}")
    text = (project / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'config/features=PackedStringArray\("(\d+\.\d+)"', text)
    if not match:
        raise BuildError("--project: project.godot 에서 엔진 버전(config/features)을 찾을 수 없습니다.")
    return match.group(1)


def check_output_dir(output_dir: Path, project: Path, engine_app: Path) -> None:
    if os.path.lexists(output_dir):
        raise BuildError(f"--output-dir: 이미 존재해서 만들지 않습니다(덮어쓰기/삭제 안 함): {output_dir}")
    if not output_dir.parent.is_dir():
        raise BuildError(f"--output-dir: 상위 폴더가 없습니다: {output_dir.parent}")
    resolved = Path(os.path.realpath(output_dir.parent)) / output_dir.name
    for label, other in (("프로젝트", project), ("Godot 앱", engine_app)):
        if is_within(resolved, other) or is_within(other, resolved):
            raise BuildError(f"--output-dir: {label} 폴더와 겹치거나 그 안/밖에 있을 수 없습니다: {other}")


def scoped_env(scratch: Path) -> dict:
    """임시/XDG 스크래치 경로만 output-dir 안으로 돌린다. HOME 은 바꾸지 않고, 호출자에게 있으면 그대로 넘긴다."""
    env = {
        "PATH": "/usr/bin:/bin",
        "LANG": "en_US.UTF-8",
        "TMPDIR": str(scratch / "tmp"),
        "XDG_CONFIG_HOME": str(scratch / "xdg-config"),
        "XDG_DATA_HOME": str(scratch / "xdg-data"),
        "XDG_CACHE_HOME": str(scratch / "xdg-cache"),
    }
    if "HOME" in os.environ:
        env["HOME"] = os.environ["HOME"]
    return env


def run_logged(args: list, log_path: Path, env: dict, cwd: Path, runner, timeout: int = STEP_TIMEOUT) -> int:
    """인자 배열로(셸 없이) 실행하고 명령/출력/종료 코드를 로그에 남긴다."""
    with open(log_path, "a", encoding="utf-8") as log:
        log.write("$ " + " ".join(shlex.quote(a) for a in args) + "\n")
        log.flush()
        try:
            proc = runner(args, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                          cwd=str(cwd), env=env, timeout=timeout, check=False, shell=False)
        except subprocess.TimeoutExpired:
            raise BuildError(f"{timeout}초 안에 끝나지 않았습니다: {args[0]} (로그: {log_path})")
        except OSError as err:
            raise BuildError(f"실행하지 못했습니다: {args[0]}: {err} (로그: {log_path})")
        log.write(f"\n[exit status {proc.returncode}]\n")
    return proc.returncode


def build_snapshot(project: Path, snapshot: Path) -> dict:
    """허용 목록의 파일만 snapshot 으로 복사한다. 심볼릭 링크는 거부, 숨김/자격 증명 모양 파일은 제외한다."""
    included, excluded = [], []
    snapshot.mkdir()
    if (project / "project.godot").is_symlink():
        raise BuildError(f"--project: project.godot 가 심볼릭 링크입니다: {project / 'project.godot'}")
    shutil.copy2(project / "project.godot", snapshot / "project.godot")
    included.append("project.godot")
    for top in ALLOWED_DIRS:
        src_top = project / top
        if not src_top.exists() and not src_top.is_symlink():
            continue
        if src_top.is_symlink() or not src_top.is_dir():
            raise BuildError(f"--project: {top} 는 심볼릭 링크가 아닌 폴더여야 합니다.")
        for root, dirs, files in os.walk(src_top, followlinks=False):
            root_path = Path(root)
            for name in list(dirs):
                if (root_path / name).is_symlink():
                    raise BuildError(f"--project: 심볼릭 링크는 번들에 넣지 않습니다: {root_path / name}")
                if name.startswith("."):
                    dirs.remove(name)
                    excluded.append(str((root_path / name).relative_to(project)) + "/")
            dirs.sort()
            for name in sorted(files):
                path = root_path / name
                rel = path.relative_to(project).as_posix()
                if path.is_symlink():
                    raise BuildError(f"--project: 심볼릭 링크는 번들에 넣지 않습니다: {path}")
                if name.startswith(".") or any(fnmatch(name.lower(), pat) for pat in SECRET_PATTERNS):
                    excluded.append(rel)
                    continue
                dest = snapshot / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, dest)
                included.append(rel)
    return {"included": included, "excluded": excluded}


def export_presets_text() -> str:
    # 경로를 넣지 않는 고정 텍스트다. 스크립트는 평문 .gd 로 내보내 qa_capture.gd 를 그대로 쓴다.
    return (
        "[preset.0]\n\n"
        f'name="{PRESET_NAME}"\n'
        'platform="macOS"\n'
        "runnable=false\n"
        "dedicated_server=false\n"
        'custom_features=""\n'
        'export_filter="all_resources"\n'
        # Raw licenses are not importable resources; include them explicitly.
        'include_filter="assets/fonts/*OFL.txt,assets/ui/material-rounded/LICENSE.txt"\n'
        'exclude_filter=""\n'
        'export_path=""\n'
        "script_export_mode=0\n"
        "encrypt_pck=false\n"
        "encrypt_directory=false\n\n"
        "[preset.0.options]\n\n"
        'application/bundle_identifier="local.ramenatelier.qa"\n'
    )


def verify_pack(pack: Path) -> None:
    if not pack.is_file() or pack.stat().st_size == 0:
        raise BuildError(f"PCK 가 만들어지지 않았습니다: {pack}")
    data = pack.read_bytes()
    if data[:4] != b"GDPC":
        raise BuildError(f"PCK 헤더(GDPC)가 아닙니다: {pack}")
    if b"tests/qa_capture.gd" not in data:
        raise BuildError("PCK 에 tests/qa_capture.gd 가 없습니다.")
    for marker in FORBIDDEN_IN_PACK:
        if marker in data:
            raise BuildError(f"PCK 에 들어가면 안 되는 항목이 있습니다: {marker.decode()}")


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def launcher_script(output_dir: Path, engine: Path, pack: Path, qa_script: str = QA_SCRIPT) -> str:
    """고정 경로 세 개만 shlex.quote 로 박고, 나머지는 변수를 큰따옴표로만 쓴다(eval/보간 없음)."""
    q = shlex.quote
    return f"""#!/bin/sh
# 생성된 로컬 QA 런처. 실제 렌더러로 실행하며 헤드리스/레이아웃 전용으로 자동 전환하지 않는다.
OUT={q(str(output_dir))}
ENGINE={q(str(engine))}
PACK={q(str(pack))}
fail() {{
  printf '%s %s\\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$OUT/launcher-errors.log"
  exit "$2"
}}
# 엔진이 getcwd 를 호출하므로 앱 실행 환경이 준 해석 불가능한 작업 폴더 대신 읽기 전용의 안정적인 '/' 에서 실행한다.
# 모든 엔진/PCK/로그/QA 출력/데이터/tmp 경로는 절대 경로이며 output-dir 안에만 있고 '/' 아래에는 아무것도 쓰지 않는다.
cd / || fail "cannot enter stable working directory /" 70
LAUNCH_CWD="$(pwd -P)" && [ "$LAUNCH_CWD" = "/" ] || fail "stable working directory did not resolve to / (got: $LAUNCH_CWD)" 76
[ -x "$ENGINE" ] || fail "engine not executable" 71
[ -f "$PACK" ] || fail "pack missing" 72
RUN="$OUT/runs/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir "$RUN" || fail "cannot create fresh run dir" 73
mkdir "$RUN/captures" "$RUN/qa-data" "$RUN/tmp" || fail "cannot create run subdirs in $RUN" 74
printf '%s\\n' "$RUN" > "$OUT/latest-run.txt"
printf 'started_utc=%s\\nlaunch_cwd=%s\\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LAUNCH_CWD" > "$RUN/started.txt"
TMPDIR="$RUN/tmp" "$ENGINE" --main-pack "$PACK" --log-file "$RUN/godot.log" \\
  --script {q(qa_script)} -- "--qa-out=$RUN/captures" "--dev-data-dir=$RUN/qa-data" > "$RUN/console.log" 2>&1
STATUS=$?
printf 'exit_status=%s\\nfinished_utc=%s\\n' "$STATUS" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RUN/exit-status.txt"
exit "$STATUS"
"""


def copy_engine(output_dir: Path, engine_app: Path, engine_name: str) -> tuple:
    """공급자 Info.plist/실행 파일/서명을 그대로 보존하고 QA 런처와 별도 위치에 복사한다."""
    runtime = output_dir / RUNTIME_DIR
    runtime.mkdir()
    dest = runtime / engine_app.name
    # 일부 Python 빌드에는 xattr API가 없어 copytree가 quarantine 등 속성을 놓친다.
    # macOS 기본 복사 도구로 보안 속성/ACL/심볼릭 링크까지 유지한다. 목적지는 새 폴더뿐이다.
    if sys.platform == "darwin":
        copied = subprocess.run(["/usr/bin/ditto", "--rsrc", "--extattr", "--acl", str(engine_app), str(dest)],
                                capture_output=True, text=True, check=False)
        if copied.returncode:
            raise BuildError(f"공급자 엔진 복사에 실패했습니다: {copied.stderr.strip()}")
    else:
        shutil.copytree(engine_app, dest, symlinks=True)
    # Finder의 표시 정보는 Documents 복사본에 상속될 수 있으며 엄격 서명 검증이 거부한다.
    # 소유한 복사본의 해당 속성만 제거한다. quarantine/provenance 등 보안 속성과 원본은 보존한다.
    if sys.platform == "darwin":
        for copied_path in (dest, *dest.rglob("*")):
            if copied_path.is_symlink():
                continue
            listed = subprocess.run(["/usr/bin/xattr", str(copied_path)],
                                    capture_output=True, text=True, check=False)
            if listed.returncode:
                raise BuildError(f"복사한 엔진의 표시 속성을 확인하지 못했습니다: {copied_path}: {listed.stderr.strip()}")
            if "com.apple.FinderInfo" in listed.stdout.splitlines():
                removed = subprocess.run(["/usr/bin/xattr", "-d", "com.apple.FinderInfo", str(copied_path)],
                                         capture_output=True, text=True, check=False)
                if removed.returncode:
                    raise BuildError(f"복사한 엔진의 Finder 표시 속성을 정리하지 못했습니다: {copied_path}: {removed.stderr.strip()}")
    # 과거 개발 실행에서 원본 번들 안에 추가한 빈 포터블 마커만 복사본에서 제외한다.
    # 공급자 번들 안의 추가 파일은 엄격 서명 검증을 깨뜨린다. 원본/서명/실행 파일은 변경하지 않는다.
    copied_marker = dest / "Contents" / "MacOS" / PORTABLE_MARKER
    if copied_marker.exists() or copied_marker.is_symlink():
        if copied_marker.is_symlink() or not copied_marker.is_file() or copied_marker.stat().st_size != 0:
            raise BuildError("복사된 엔진 안의 포터블 마커가 빈 일반 파일이 아닙니다. 자동 정리하지 않습니다.")
        copied_marker.unlink()
    with open(runtime / PORTABLE_MARKER, "x", encoding="utf-8"):
        pass
    return dest, dest / "Contents" / "MacOS" / engine_name


def assemble_app(output_dir: Path, dest: Path, engine: Path, pack: Path, qa_script: str = QA_SCRIPT) -> Path:
    # 공급자 앱의 CFBundleExecutable/Identifier를 바꾸면 Mach-O 서명이 깨진다.
    # 자체 제작 런처 앱만 새로 쓰고, 엔진은 서명이 유효한 별도 번들을 참조한다.
    (dest / "Contents" / "MacOS").mkdir(parents=True)
    resources = dest / "Contents" / "Resources"
    resources.mkdir(exist_ok=True)
    packed = resources / PACK_NAME
    shutil.copy2(pack, packed)
    launcher = dest / "Contents" / "MacOS" / LAUNCHER_NAME
    with open(launcher, "x", encoding="utf-8") as fh:
        fh.write(launcher_script(output_dir, engine, packed, qa_script))
    os.chmod(launcher, 0o755)
    plist_path = dest / "Contents" / "Info.plist"
    digest = hashlib.sha256(str(output_dir).encode("utf-8")).hexdigest()[:10]
    info = {
        "CFBundleExecutable": LAUNCHER_NAME,
        "CFBundleIdentifier": f"local.ramenatelier.dev.qa.{digest}",
        "CFBundleName": "Ramen QA",
        "CFBundleDisplayName": "Ramen QA",
        "CFBundleShortVersionString": "0.1-local",
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1",
    }
    with open(plist_path, "wb") as fh:
        plistlib.dump(info, fh)
    return dest


def prepare(godot: Path, project: Path, output_dir: Path, runner=subprocess.run, platform: str = sys.platform, qa_script: str = QA_SCRIPT) -> dict:
    # 1) 부작용 없는 검증. 여기서 실패하면 output-dir 을 만들지 않는다.
    engine_app = verify_engine(godot, platform)
    check_project_source(project)
    # Only two reviewed project-owned fixtures; no raw command or arbitrary path.
    if qa_script not in (QA_SCRIPT, "res://tests/bowl_editor_qa.gd"):
        raise BuildError("Unsupported QA fixture.")
    if not (project / qa_script.removeprefix("res://")).is_file():
        raise BuildError("Selected QA fixture is missing.")
    check_output_dir(output_dir, project, engine_app)
    series = project_engine_series(project)

    # 2) 이 아래부터는 output-dir 이 생기므로 실패해도 prep/ 에 진단을 남긴다.
    output_dir.mkdir()
    prep = output_dir / "prep"
    try:
        (prep / "tmp").mkdir(parents=True)
        (output_dir / "runs").mkdir()
        env = scoped_env(prep)
        # 원본 엔진은 실행하지 않는다. 복사본(+_sc_ 마커)으로 준비와 런타임을 모두 하므로 editor_data 도 output-dir 안에 생긴다.
        runtime_app, engine = copy_engine(output_dir, engine_app, godot.name)
        signature_verified = False
        if (runtime_app / "Contents" / "_CodeSignature").is_dir():
            signature_log = prep / "engine-signature.log"
            if run_logged(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", str(runtime_app)],
                          signature_log, env, prep, runner, timeout=60) != 0:
                raise BuildError(f"복사한 공급자 엔진 서명 검증이 실패했습니다(로그: {signature_log})")
            signature_verified = True

        version_log = prep / "godot-version.log"
        if run_logged([str(engine), "--version"], version_log, env, prep, runner, timeout=60) != 0:
            raise BuildError(f"Godot --version 이 실패했습니다(로그: {version_log})")
        found = re.search(r"^(\d+\.\d+)\.", version_log.read_text(encoding="utf-8", errors="replace"), re.M)
        if not found or found.group(1) != series:
            raise BuildError(f"엔진 버전이 프로젝트({series})와 맞지 않습니다(로그: {version_log})")
        version_text = [ln for ln in version_log.read_text(encoding="utf-8", errors="replace").splitlines()
                        if re.match(r"\d+\.\d+\.", ln)][0]

        snapshot = prep / "project"
        scope = build_snapshot(project, snapshot)
        (snapshot / "export_presets.cfg").write_text(export_presets_text(), encoding="utf-8")

        import_log = prep / "import.log"
        if run_logged([str(engine), "--headless", "--path", str(snapshot), "--editor", "--import", "--quit"],
                      import_log, env, prep, runner) != 0:
            raise BuildError(f"헤드리스 import 가 실패했습니다(로그: {import_log})")
        pack = prep / PACK_NAME
        export_log = prep / "export.log"
        if run_logged([str(engine), "--headless", "--path", str(snapshot), "--export-pack", PRESET_NAME, str(pack)],
                      export_log, env, prep, runner) != 0:
            raise BuildError(f"--export-pack 이 실패했습니다(로그: {export_log})")
        verify_pack(pack)

        if qa_script.removeprefix("res://").encode("utf-8") not in pack.read_bytes():
            raise BuildError("Selected QA fixture was not exported.")
        app = assemble_app(output_dir, output_dir / APP_NAME, engine, pack, qa_script)
        manifest = {
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "godot": str(godot), "godot_version": version_text, "godot_sha256": sha256_of(godot),
            "project_source": str(project), "pack_sha256": sha256_of(pack),
            "copied_godot": str(engine), "vendor_signature_verified": signature_verified,
            "bundled_files": scope["included"], "excluded_files": scope["excluded"],
            "local_development_only": True,
            "qa_script": qa_script,
        }
        (prep / "build-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (BuildError, OSError, shutil.Error) as err:
        stamp = datetime.now(timezone.utc).isoformat()
        try:
            prep.mkdir(parents=True, exist_ok=True)
            (prep / "FAILED.txt").write_text(f"{stamp}\n{err}\n", encoding="utf-8")
        except OSError as diag_err:
            raise BuildError(f"{err} (진단 기록 실패: FAILED.txt 를 쓰지 못했습니다: {diag_err}; 위치: {prep})")
        raise BuildError(f"{err} (진단 보존: {prep})")
    return {"app": app, "pack": pack, "manifest": prep / "build-manifest.json"}


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(description="자체 포함 로컬 QA 앱 생성기(실행은 하지 않음)")
    ap.add_argument("--godot", required=True, help="Godot.app/Contents/MacOS/Godot 절대 경로")
    ap.add_argument("--project", required=True, help="game 프로젝트 폴더 절대 경로")
    ap.add_argument("--output-dir", required=True, help="아직 없는 새 폴더의 절대 경로")
    ap.add_argument("--fixture", choices=("full", "bowl-editor"), default="full", help="검토한 네이티브 검사 흐름")
    args = ap.parse_args(argv)
    try:
        godot = absolute_path("--godot", args.godot)
        project = absolute_path("--project", args.project)
        output_dir = absolute_path("--output-dir", args.output_dir)
        if not project.is_dir():
            raise BuildError(f"--project: 폴더가 아닙니다: {project}")
        entry = QA_SCRIPT if args.fixture == "full" else "res://tests/bowl_editor_qa.gd"
        result = prepare(godot, project, output_dir, qa_script=entry)
    except (BuildError, OSError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    print(f"prepared (not yet run): {result['app']}")
    print(f"pack: {result['pack']}")
    print(f"manifest: {result['manifest']}")
    print("준비 성공은 그래픽 성공이 아닙니다. 앱을 실행한 뒤 runs/<시각>/ 의 캡처·exit-status.txt·godot.log 를 확인하세요.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
