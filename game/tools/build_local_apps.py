#!/usr/bin/env python3
"""로컬 개발용 macOS 런처 앱 두 개를 만든다 (Ramen Atelier.app, Ramen QA.app).

각 앱은 셸 스크립트 하나와 Info.plist 만 가진 얇은 번들이며, 지정한 Godot 실행 파일을
프로젝트 경로와 함께 exec 한다. 엔진을 복사하지 않고, 서명/배포용 바이너리도 아니다.
이 스크립트는 파일만 쓴다(Godot 실행, GUI 자동화, 네트워크, 삭제 없음). 표준 라이브러리만 사용한다.
"""
import argparse
import hashlib
import os
import plistlib
import shlex
import sys
from pathlib import Path

APPS = (
    {"name": "Ramen Atelier", "slug": "atelier", "qa": False},
    {"name": "Ramen QA", "slug": "qa", "qa": True},
)


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


def ensure_dir(label: str, path: Path) -> None:
    if path.exists() and not path.is_dir():
        raise BuildError(f"{label}: 폴더가 아닌 항목이 이미 있습니다: {path}")
    path.mkdir(parents=True, exist_ok=True)


def launcher_script(app: dict, godot: Path, project: Path, log_file: Path, data_dir: Path, qa_out: Path) -> str:
    q = shlex.quote
    parts = [
        "exec", q(str(godot)),
        "--path", q(str(project)),
        "--log-file", q(str(log_file)),
    ]
    if app["qa"]:
        # QA 는 --headless 없이 실제 렌더러로 실행한다. 저장은 data-dir 아래 별도 qa 폴더만 쓴다.
        parts += ["--script", q("res://tests/qa_capture.gd"), "--",
                  q(f"--qa-out={qa_out}"), q(f"--dev-data-dir={data_dir / 'qa'}")]
    else:
        parts += ["--", q(f"--dev-data-dir={data_dir}")]
    # LaunchServices 가 쓸 수 없는 현재 디렉터리로 앱을 시작할 수 있다(getcwd 오류, res:// 스크립트를
    # 열지 못함). 그래서 검증된 프로젝트 폴더로 명시적으로 이동하고, 실패하면 비정상 종료한다.
    return "#!/bin/sh\n" + f"cd {q(str(project))} || exit 1\n" + " ".join(parts) + "\n"


def bundle_id(app: dict, output_dir: Path) -> str:
    digest = hashlib.sha256(f"{output_dir}|{app['slug']}".encode("utf-8")).hexdigest()[:10]
    return f"local.ramenatelier.dev.{app['slug']}.{digest}"


def build_bundle(app: dict, dest: Path, output_dir: Path, script: str) -> None:
    macos = dest / "Contents" / "MacOS"
    # exist_ok=False: 이미 있으면 실패한다(덮어쓰기/삭제 없음).
    macos.mkdir(parents=True, exist_ok=False)
    plist = {
        "CFBundleName": app["name"],
        "CFBundleDisplayName": app["name"],
        "CFBundleIdentifier": bundle_id(app, output_dir),
        "CFBundleExecutable": "launcher",
        "CFBundlePackageType": "APPL",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "0.1-local",
        "LSMinimumSystemVersion": "11.0",
        "NSHighResolutionCapable": True,
    }
    with open(dest / "Contents" / "Info.plist", "xb") as fh:
        plistlib.dump(plist, fh)
    launcher = macos / "launcher"
    with open(launcher, "x", encoding="utf-8") as fh:
        fh.write(script)
    os.chmod(launcher, 0o755)


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(description="로컬 개발용 Godot 런처 앱 생성기")
    ap.add_argument("--godot", required=True, help="Godot 실행 파일 절대 경로")
    ap.add_argument("--project", required=True, help="game 프로젝트 폴더 절대 경로")
    ap.add_argument("--output-dir", required=True, help="앱 번들과 로그를 둘 절대 경로")
    ap.add_argument("--data-dir", required=True, help="개발용 저장 폴더 절대 경로")
    ap.add_argument("--qa-out", required=True, help="QA 스크린샷 폴더 절대 경로")
    args = ap.parse_args(argv)

    try:
        godot = absolute_path("--godot", args.godot)
        project = absolute_path("--project", args.project)
        output_dir = absolute_path("--output-dir", args.output_dir)
        data_dir = absolute_path("--data-dir", args.data_dir)
        qa_out = absolute_path("--qa-out", args.qa_out)

        if not godot.is_file() or not os.access(godot, os.X_OK):
            raise BuildError(f"--godot: 실행 가능한 파일이 아닙니다: {godot}")
        if not project.is_dir() or not (project / "project.godot").is_file():
            raise BuildError(f"--project: project.godot 이 있는 폴더가 아닙니다: {project}")

        destinations = []
        for app in APPS:
            dest = output_dir / f"{app['name']}.app"
            # 출력은 반드시 output-dir 바로 아래여야 한다.
            if dest.parent != output_dir:
                raise BuildError(f"출력 위치가 output-dir 밖입니다: {dest}")
            if os.path.lexists(dest):
                raise BuildError(f"이미 존재해서 만들지 않습니다(덮어쓰기 안 함): {dest}")
            destinations.append(dest)

        ensure_dir("--output-dir", output_dir)
        ensure_dir("--data-dir", data_dir)
        ensure_dir("--data-dir/qa", data_dir / "qa")
        ensure_dir("--qa-out", qa_out)

        for app, dest in zip(APPS, destinations):
            log_file = output_dir / f"{app['slug']}.log"
            script = launcher_script(app, godot, project, log_file, data_dir, qa_out)
            build_bundle(app, dest, output_dir, script)
            print(f"created: {dest}")
    except (BuildError, OSError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
