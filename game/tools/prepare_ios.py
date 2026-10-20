#!/usr/bin/env python3
"""Stage a portrait iPhone project without editing the accepted Mac sources.

No GUI, downloads, account/keychain inspection, signing or device installation.
Optional export only generates an Xcode project, using an explicitly supplied
RAMEN_IOS_TEAM_ID. Never invent an identity or silently accept an engine error.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import zipfile

import build_qa_app as shared

VERSION = "4.7.2.stable"
# Hash of ios.zip extracted from the official standard4.7.2 TPZ, whose
# SHA256 and published SHA512 were independently verified before staging.
IOS_SHA256 = "fd3280d10dc75356dded006f6f8813f40a5aebd32d128592b781256d8ffbdff4"
PRESET = "Ramen iPhone Development"


def require(ok, message):
    if not ok:
        raise shared.BuildError(message)


def verify_template(path):
    """Reject links/corruption before creating any output; never extract ZIP paths."""
    require(not path.is_symlink() and path.is_file(), "iOS template must be a regular file.")
    require(shared.sha256_of(path) == IOS_SHA256, "Official iOS template hash mismatch.")
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        require(sum(row.file_size for row in entries) < 2 * 1024**3, "Unexpected template size.")
        for row in entries:
            name = Path(row.filename)
            require(not name.is_absolute() and ".." not in name.parts and "\\" not in row.filename,
                    "Unsafe template member.")
            require(not stat.S_ISLNK(row.external_attr >> 16), "Template links are not supported.")
        require("godot_apple_embedded.xcodeproj/project.pbxproj" in archive.namelist(),
                "Xcode project template missing.")


def preset_text(template, team):
    # Values are JSON-quoted rather than inserted as executable shell text.
    # Export remains project-only even when a real team has been supplied.
    q = lambda value: json.dumps(str(value), ensure_ascii=False)
    return f'''[preset.0]
name={q(PRESET)}
platform="iOS"
runnable=true
advanced_options=true
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*,tools/*,docs/*"
export_path="../xcode/RamenAtelier.ipa"
script_export_mode=2

[preset.0.options]
custom_template/debug={q(template)}
custom_template/release={q(template)}
architectures/arm64=true
application/app_store_team_id={q(team)}
application/bundle_identifier="local.ramenatelier.dev.ios.v0"
application/short_version="0.11"
application/version="11.0.0"
application/targeted_device_family=0
application/min_ios_version="17.0"
application/export_method_debug=1
application/export_project_only=true
application/delete_old_export_files_unconditionally=false
modules/camera=false
entitlements/game_center=false
entitlements/push_notifications=""
icons/icon_1024x1024="res://ios-development-icon.svg"
'''


def development_icon_svg():
    # A provisional opaque development icon; no release branding is implied.
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<rect width="1024" height="1024" fill="#f6e7c7"/>
<path d="M240 460H784C760 670 654 756 512 756S264 670 240 460Z" fill="#b54135"/>
<ellipse cx="512" cy="460" rx="272" ry="84" fill="#462d25"/>
<ellipse cx="512" cy="460" rx="226" ry="54" fill="#d9a95b"/>
<path d="M390 420C358 374 448 342 414 284M518 420C486 374 576 342 542 284M646 420C614 374 704 342 670 284" fill="none" stroke="#8a643f" stroke-width="20" stroke-linecap="round"/>
</svg>
'''


def override_text():
    # A staging-only logical baseline, not a claim about real safe areas/DPI.
    # Native portrait layout, keyboard and backgrounding still need a device.
    return '''; iPhone development staging only; original project.godot is unchanged.
[display]
window/size/viewport_width=390
window/size/viewport_height=844
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[input_devices]
pointing/emulate_mouse_from_touch=true

[rendering]
; iOS export requires mobile texture imports even on a desktop host.
textures/vram_compression/import_etc2_astc=true
'''


def checked_run(args, log, env, cwd, timeout=900):
    code = shared.run_logged(args, log, env, cwd, subprocess.run, timeout=timeout)
    require(code == 0, "Command failed; see " + str(log))
    require(not re.search(r"(?im)SCRIPT ERROR|ERROR:|Parse Error", log.read_text()),
            "Engine errors despite exit0; see " + str(log))


def settings_merge_script():
    # Editors ignore runtime override.cfg. Use Godot's own config parser to
    # merge only these settings into the private snapshot, retaining every
    # other setting. The accepted source project.godot is never written.
    return '''extends SceneTree
func _initialize():
 var target = ConfigFile.new()
 var overlay = ConfigFile.new()
 if target.load("res://project.godot") != OK or overlay.load("res://override.cfg") != OK:
  push_error("Cannot load staged iOS settings")
  quit(1)
  return
 for section in overlay.get_sections():
  for key in overlay.get_section_keys(section):
   target.set_value(section, key, overlay.get_value(section, key))
 if target.save("res://project.godot") != OK:
  push_error("Cannot save staged iOS settings")
  quit(1)
  return
 quit(0)
'''


def prepare(godot, project, template, output, export=False, team=""):
    engine_app = shared.verify_engine(godot, sys.platform)
    shared.check_project_source(project)
    shared.check_output_dir(output, project, engine_app)
    require(not shared.is_within(template, output), "Template must be outside fresh output.")
    require(shared.project_engine_series(project) == "4.7", "Expected Godot4.7 project.")
    verify_template(template)
    require(not team or re.fullmatch(r"[A-Z0-9]{10}", team), "Team ID must contain10 uppercase letters/digits.")
    require(not export or team, "Export needs a real RAMEN_IOS_TEAM_ID from the user's Xcode team.")

    output.mkdir()
    prep = output / "prep"
    prep.mkdir()
    try:
        for name in ("tmp", "xdg-config", "xdg-data", "xdg-cache"):
            (prep / name).mkdir()
        env = shared.scoped_env(prep)
        runtime, engine = shared.copy_engine(output, engine_app, godot.name)
        checked_run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(runtime)],
                    prep / "signature.log", env, prep, 60)
        checked_run([str(engine), "--version"], prep / "version.log", env, prep, 60)
        require(VERSION in (prep / "version.log").read_text(), "Engine/template exact version mismatch.")
        snapshot = prep / "project"
        scope = shared.build_snapshot(project, snapshot)
        original = {name: shared.sha256_of(project / name) for name in scope["included"]}
        # Godot4.7 checks the standard template path before custom presets and
        # retains its missing-template diagnostic. Install only in this copied
        # engine's self-contained data directory, never the user's global one.
        templates = runtime.parent / "editor_data" / "export_templates" / VERSION
        templates.mkdir(parents=True)
        staged_template = templates / "ios.zip"
        shutil.copy2(template, staged_template)
        require(shared.sha256_of(staged_template) == IOS_SHA256, "Copied template changed.")
        (snapshot / "override.cfg").write_text(override_text())
        (snapshot / "ios-development-icon.svg").write_text(development_icon_svg())
        (snapshot / "export_presets.cfg").write_text(preset_text(staged_template, team))
        merger = prep / "merge_ios_settings.gd"
        merger.write_text(settings_merge_script())
        checked_run([str(engine), "--headless", "--path", str(snapshot), "--script", str(merger)],
                    prep / "settings-merge.log", env, prep, 60)
        # Only the copied project configuration intentionally differs. Freeze
        # its new digest too, so later import/export mutations remain failures.
        staged = dict(original)
        staged["project.godot"] = shared.sha256_of(snapshot / "project.godot")
        checked_run([str(engine), "--headless", "--path", str(snapshot), "--editor", "--import", "--quit"],
                    prep / "import.log", env, prep)
        xcode = output / "xcode"
        xcode.mkdir()
        if export:
            checked_run([str(engine), "--headless", "--path", str(snapshot), "--export-debug", PRESET, str(xcode / "RamenAtelier.ipa")],
                        prep / "export.log", env, prep)
            require((xcode / "RamenAtelier.xcodeproj/project.pbxproj").is_file(), "Exported Xcode project missing.")
        require(all(shared.sha256_of(project / name) == digest and
                    shared.sha256_of(snapshot / name) == staged[name] for name, digest in original.items()),
                "Original or staged game source changed during import/export.")
        checked_run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(runtime)],
                    prep / "signature-after.log", env, prep, 60)
        report = {"status": "xcode_project_exported_not_built" if export else "staged_not_exported",
                  "version": VERSION, "template_sha256": IOS_SHA256, "source_sha256": original,
                  "staged_sha256": staged, "staging_config_changed": ["project.godot"],
                  "source_count": len(original), "excluded": scope["excluded"],
                  "team_configured": bool(team), "preset": PRESET,
                  "xcode_project": str(xcode / "RamenAtelier.xcodeproj") if export else None,
                  "ios_app_built": False, "signed": False, "device_tested": False,
                  "needs": ["Compatible Xcode/iOS SDK", "Apple account and real signing team", "Connected trusted iPhone and actual device tests"],
                  "mac_source_preserved": True, "live_save_accessed": False}
        (output / "preparation.json").write_text(json.dumps(report, indent=2) + "\n")
        return report
    except (shared.BuildError, OSError, zipfile.BadZipFile) as error:
        try:
            (prep / "FAILED.txt").write_text(str(error) + "\n")
        except OSError as diagnostic_error:
            raise shared.BuildError(f"{error}; could not preserve FAILED.txt: {diagnostic_error}") from error
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("godot", "project", "ios-template", "output-dir"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--export-project", action="store_true")
    args = parser.parse_args()
    try:
        paths = [shared.absolute_path(name, value) for name, value in
                 [("godot", args.godot), ("project", args.project), ("ios-template", args.ios_template), ("output-dir", args.output_dir)]]
        report = prepare(*paths, export=args.export_project, team=os.environ.get("RAMEN_IOS_TEAM_ID", ""))
    except (shared.BuildError, OSError, zipfile.BadZipFile) as error:
        print("iOS preparation failed: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps({key: report[key] for key in ("status", "source_count", "team_configured", "ios_app_built", "device_tested")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
