#!/usr/bin/env python3
"""Read-only mechanical checks for frozen native QA; never certify visual quality.

The spec pins one Git commit and one already-finished run. Only git show and
codesign verification are executed; the game, launcher and engine are not run.
PNG structure/dimensions are checked, not pixel appearance or human usability.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import zlib


class AuditError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise AuditError(message)


def absolute(value):
    require(isinstance(value, str) and Path(value).is_absolute(), "Absolute path required")
    path = Path(value)
    require(".." not in path.parts, "Parent traversal is not allowed")
    return path


def scoped(root, relative):
    """Reject symlink components before reading; never follow input escape paths."""
    require(isinstance(relative, str) and relative and not Path(relative).is_absolute(), "Relative child path required")
    require(all(p and p not in ("..", ".") for p in relative.split("/")), "Invalid child path")
    result = root
    for part in Path(relative).parts:
        result = result / part
        require(not result.is_symlink(), "Symlink input refused: " + relative)
    require(result.resolve().is_relative_to(root.resolve()), "Input escapes its scope")
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fields(path, expected):
    lines = path.read_text(encoding="utf-8").splitlines()
    pairs = [line.split("=", 1) for line in lines]
    require(all(len(pair) == 2 for pair in pairs), "Malformed run metadata")
    result = dict(pairs)
    require(len(result) == len(pairs) and set(result) == set(expected), "Unexpected or duplicate run metadata")
    return result


def timestamp(value):
    require(isinstance(value, str) and re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value), "UTC run timestamp required")
    return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()


def png_dimensions(path):
    """Validate every chunk CRC, including image data, without claiming to render it."""
    require(0 < path.stat().st_size <= 32 * 1024 * 1024, "Unexpected PNG size")
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG signature")
    offset, dimensions, saw_data, ended = 8, None, False, False
    while offset < len(data):
        require(offset + 12 <= len(data), "Truncated PNG chunk")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        require(end <= len(data), "PNG chunk exceeds file")
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack(">I", data[end - 4:end])[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == crc, "PNG chunk CRC mismatch")
        if dimensions is None:
            require(kind == b"IHDR" and length == 13, "PNG must begin with IHDR")
            dimensions = struct.unpack(">II", payload[:8])
            require(min(dimensions) > 0, "Empty PNG dimensions")
        else:
            require(kind != b"IHDR", "Duplicate PNG header")
        saw_data = saw_data or kind == b"IDAT"
        if kind == b"IEND":
            require(length == 0 and end == len(data) and saw_data, "Invalid PNG end")
            ended = True
            break
        offset = end
    require(ended, "Incomplete PNG")
    return dimensions


def git_source(repo, revision, relative):
    # A full hexadecimal commit ID cannot be interpreted as a git option.
    result = subprocess.run(["git", "show", revision + ":game/" + relative], cwd=repo,
                            capture_output=True, check=False)
    require(result.returncode == 0, "Source commit/file unavailable: " + relative)
    return result.stdout


def official_signature(engine):
    app = engine.parents[2]
    require(app.suffix == ".app", "Expected bundled official engine app")
    result = subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
                            capture_output=True, check=False)
    require(result.returncode == 0, "Official engine signature verification failed")


def audit(spec, source_reader=git_source, signature_checker=official_signature):
    required = {"app_root", "run_id", "git_repo", "source_revision", "summary_prefix",
                "expected_checks", "profiles", "baseline_data", "save_files",
                "expected_pack_sha256", "expected_engine_sha256"}
    require(isinstance(spec, dict) and set(spec) == required, "Unexpected audit specification fields")
    root, repo, baseline = (absolute(spec[key]) for key in ("app_root", "git_repo", "baseline_data"))
    require(all(path.is_dir() and not path.is_symlink() for path in (root, repo, baseline)), "Input roots must be real directories")
    revision = spec["source_revision"]
    require(isinstance(revision, str) and re.fullmatch(r"[0-9a-f]{40}", revision), "Full Git commit ID required")
    require(re.fullmatch(r"\d{8}T\d{6}Z-\d+", spec["run_id"]), "Explicit run ID required")
    run = scoped(root, "runs/" + spec["run_id"])
    start = fields(scoped(run, "started.txt"), ("started_utc", "launch_cwd"))
    finish = fields(scoped(run, "exit-status.txt"), ("exit_status", "finished_utc"))
    require(start["launch_cwd"] == "/" and finish["exit_status"] == "0", "Native run did not finish successfully")
    begin, end = timestamp(start["started_utc"]), timestamp(finish["finished_utc"])
    require(end >= begin, "Run finishes before it starts")
    console = re.sub(r"\x1b\[[0-9;]*m", "", scoped(run, "console.log").read_text(encoding="utf-8"))
    require(not re.search(r"(?m)^\s*(?:SCRIPT ERROR|ERROR|WARNING|FAIL):", console), "Engine error/warning/failure in console")
    require("LAYOUT ONLY" not in console and "mode=layout" not in console, "Layout-only execution is not native evidence")
    prefix = spec["summary_prefix"]
    require(isinstance(prefix, str) and prefix and "\n" not in prefix, "Summary prefix required")
    summaries = re.findall(r"(?m)^" + re.escape(prefix) + r" checks=(\d+) failures=(\d+) mode=capture$", console)
    require(type(spec["expected_checks"]) is int and spec["expected_checks"] > 0, "Positive expected check count required")
    require(summaries == [(str(spec["expected_checks"]), "0")], "Missing, duplicate or failing capture-mode summary")
    # The engine's separate log can contain diagnostics absent from stdout.
    engine_log = re.sub(r"\x1b\[[0-9;]*m", "", scoped(run, "godot.log").read_text(encoding="utf-8"))
    require(not re.search(r"(?m)^\s*(?:SCRIPT ERROR|ERROR|WARNING|FAIL):", engine_log), "Engine log contains diagnostics")
    manifest = json.loads(scoped(root, "prep/build-manifest.json").read_text(encoding="utf-8"))
    files = manifest["bundled_files"]
    require(isinstance(files, list) and files and len(set(files)) == len(files), "Missing or duplicate source manifest")
    source_hashes = {}
    for relative in files:
        require(relative == "project.godot" or relative.split("/")[0] in {"scenes", "scripts", "tests", "assets", "licenses"}, "Unexpected source scope")
        path = scoped(root, "prep/project/" + relative)
        content = path.read_bytes()
        require(content == source_reader(repo, revision, relative), "Frozen source mismatch: " + relative)
        source_hashes[relative] = hashlib.sha256(content).hexdigest()
    # Pin reviewed hashes separately from the mutable app manifest. Changing
    # both a binary and its manifest must not turn a different app into proof.
    for key in ("expected_pack_sha256", "expected_engine_sha256"):
        require(isinstance(spec[key], str) and re.fullmatch(r"[0-9a-f]{64}", spec[key]), "Reviewed SHA256 pin required")
    pack = scoped(root, "prep/ramen-qa.pck")
    pack_hash = digest(pack)
    require(pack_hash == manifest["pack_sha256"] == spec["expected_pack_sha256"], "Frozen PCK hash mismatch")
    engine = absolute(manifest["copied_godot"])
    require(engine.is_relative_to(root), "Engine escapes app root")
    engine = scoped(root, str(engine.relative_to(root)))
    require(digest(engine) == manifest["godot_sha256"] == spec["expected_engine_sha256"], "Official engine bytes changed")
    signature_checker(engine)
    profiles = spec["profiles"]
    require(isinstance(profiles, dict) and profiles, "Expected capture profiles required")
    for key, expected in profiles.items():
        require(isinstance(key, str) and re.fullmatch(r"[a-z][a-z0-9]*", key), "Invalid capture profile name")
        require(isinstance(expected, list) and len(expected) == 3 and all(type(n) is int and n > 0 for n in expected), "Profile needs width/height/count")
    captures, counts = [], dict.fromkeys(profiles, 0)
    folder = scoped(run, "captures")
    for path in sorted(folder.rglob("*")):
        require(not path.is_symlink(), "Capture symlink refused")
        require(path.is_file(), "Unexpected nested capture directory")
        profile = next((key for key in profiles if path.name.startswith(key + "_")), None)
        require(profile is not None and path.suffix == ".png", "Unexpected capture file: " + path.name)
        expected = profiles[profile]
        require(png_dimensions(path) == tuple(expected[:2]), "Wrong capture dimensions: " + path.name)
        require(begin - 2 <= path.stat().st_mtime <= end + 2, "Stale/out-of-run capture: " + path.name)
        counts[profile] += 1
        captures.append({"file": path.name, "sha256": digest(path), "width": expected[0], "height": expected[1]})
    require(all(counts[key] == profiles[key][2] for key in profiles), "Missing or extra profile captures")
    require(isinstance(spec["save_files"], list) and spec["save_files"] and len(set(spec["save_files"])) == len(spec["save_files"]), "Explicit unique whole save paths required")
    saves = []
    for relative in spec["save_files"]:
        actual, before = scoped(run, "qa-data/" + relative), scoped(baseline, relative)
        require(actual.read_bytes() == before.read_bytes(), "Whole saved state mismatch: " + relative)
        saves.append({"file": relative, "sha256": digest(actual), "byte_equal": True})
    return {"mechanical_checks_passed": True, "native_run": str(run), "source_revision": revision,
            "checks": spec["expected_checks"], "actual_exit": 0, "engine_errors_warnings": 0,
            "source_files": source_hashes, "pack_sha256": pack_hash, "official_signature_exit": 0,
            "captures": captures, "whole_save_pairs": saves, "visual_review_required": True,
            "pixel_content_decoded": False, "iphone_or_human_fun_acceptance": False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args(argv)
    spec_path = absolute(str(args.spec))
    require(not spec_path.is_symlink(), "Specification symlink refused")
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    report = absolute(str(args.report))
    require(report.parent.is_dir() and not report.exists() and not report.is_symlink(), "Report must be a new file in an existing directory")
    # A report must never overwrite a source/run/baseline/spec input.
    for key in ("app_root", "git_repo", "baseline_data"):
        require(not report.resolve().is_relative_to(absolute(spec[key]).resolve()), "Report overlaps audit inputs")
    require(report.resolve() != spec_path.resolve(), "Report overlaps specification")
    result = audit(spec)
    with report.open("x", encoding="utf-8") as output:
        json.dump(result, output, indent=2)
        output.write("\n")
    print("Mechanical QA checks passed; visual review remains required: " + str(report))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, OSError, ValueError, KeyError, TypeError) as error:
        # Malformed/missing inputs fail explicitly; no success-shaped report.
        raise SystemExit("QA audit failed: " + str(error))
