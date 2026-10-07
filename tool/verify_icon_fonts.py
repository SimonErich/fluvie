#!/usr/bin/env python3
"""Verify a Flutter release's retained IconData against its bundled font outlines.

Requires Python 3.10+ and ``pip install -r tool/requirements-font-validation.txt``.
Run after ``flutter build web --release`` with the SAME Flutter SDK:

    python tool/verify_icon_fonts.py --app apps/slides --flutter-root "$FLUTTER_ROOT"

The build's .last_build_id selects its exact kernel, even when other targets have
been built in the same checkout. For archived/native assets, pass both --assets
and --icon-data (the JSON emitted by Flutter's const_finder) instead.
"""

import argparse
import hashlib
import json
import platform
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont, TTLibError


def required_icons(constants):
    """Return package-qualified families; dynamic IconData cannot be verified."""
    if constants.get("nonConstantLocations"):
        raise ValueError("Nonconstant IconData exists; a static glyph check is incomplete")
    required = defaultdict(set)
    for icon in constants["constantInstances"]:
        family = icon.get("fontFamily")
        if family is None:
            continue  # Text-font fallback, outside the icon-font contract.
        if package := icon.get("fontPackage"):
            family = f"packages/{package}/{family}"
        point = icon["codePoint"]
        if (
            isinstance(point, bool)
            or not isinstance(point, (int, float))
            or not 0 <= point <= 0x10FFFF
            or int(point) != point
        ):
            raise ValueError(f"Invalid IconData code point: {point}")
        required[family].add(int(point))
    if not required:
        raise ValueError("No named icon fonts found; refusing an empty verification")
    return required


def verify(assets, constants):
    """Check real cmap entries and nonempty outlines, including CFF fonts."""
    required = required_icons(constants)
    manifest = json.loads((assets / "FontManifest.json").read_text())
    fonts = {entry["family"]: entry["fonts"] for entry in manifest}
    report = {"assets": str(assets.resolve()), "families": {}, "errors": []}
    for family, points in sorted(required.items()):
        if family not in fonts:
            report["errors"].append(f"Missing icon font family: {family}")
            continue
        mapped, visible, files = set(), set(), []
        for entry in fonts[family]:
            path = assets / entry["asset"]
            with TTFont(path) as font:
                cmap = font.getBestCmap() or {}
                glyphs = font.getGlyphSet()
                mapped.update(points & cmap.keys())
                for point in sorted(points & cmap.keys()):
                    pen = BoundsPen(glyphs)
                    glyphs[cmap[point]].draw(pen)
                    if pen.bounds is not None:
                        left, bottom, right, top = pen.bounds
                        if right > left and top > bottom:
                            visible.add(point)
            files.append({
                "asset": entry["asset"],
                "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
        missing, empty = sorted(points - mapped), sorted(mapped - visible)
        if missing or empty:
            report["errors"].append(f"{family}: missing={missing}, empty outlines={empty}")
        report["families"][family] = {
            "assets": files,
            "requiredGlyphs": len(points),
            "verifiedGlyphOutlines": len(visible),
        }
    return report


def scan_kernel(app, build_dir, flutter_root):
    """Use Flutter's own constant finder from the SDK which produced the build."""
    build_id = (build_dir / ".last_build_id").read_text().strip()
    if not re.fullmatch(r"[a-f0-9]{32}", build_id):
        raise ValueError(f"Invalid Flutter build ID: {build_id!r}")
    kernel = app / ".dart_tool/flutter_build" / build_id / "app.dill"
    if not kernel.is_file():
        raise ValueError(f"The release kernel is missing: {kernel}")
    host = {"darwin": "darwin", "win32": "windows"}.get(sys.platform, "linux")
    machine = platform.machine().lower()
    arch = {"x86_64": "x64", "amd64": "x64", "aarch64": "arm64"}.get(machine, machine)
    engine = flutter_root / "bin/cache/artifacts/engine"
    preferred = engine / f"{host}-{arch}/const_finder.dart.snapshot"
    snapshots = [preferred] if preferred.is_file() else sorted(
        engine.glob(f"{host}-*/const_finder.dart.snapshot")
    )
    if len(snapshots) != 1:
        raise ValueError(
            f"Expected one host const_finder snapshot in {flutter_root}; "
            f"found {len(snapshots)}"
        )
    dart = flutter_root / "bin/cache/dart-sdk/bin" / ("dart.exe" if sys.platform == "win32" else "dart")
    result = subprocess.run([
        str(dart), str(snapshots[0]), "--kernel-file", str(kernel),
        "--class-library-uri", "package:flutter/src/widgets/icon_data.dart",
        "--class-name", "IconData", "--annotation-class-name", "_StaticIconProvider",
        "--annotation-class-library-uri", "package:flutter/src/widgets/icon_data.dart",
    ], capture_output=True, text=True, check=True)
    return json.loads(result.stdout), kernel


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--app", type=Path, help="Flutter app root (release-web mode)")
    parser.add_argument("--flutter-root", type=Path, help="The SDK used to build the app")
    parser.add_argument("--build-dir", type=Path, help="Web output directory; defaults to APP/build/web")
    parser.add_argument("--assets", type=Path, help="Archived flutter_assets/assets directory (with --icon-data)")
    parser.add_argument("--icon-data", type=Path, help="Archived const_finder JSON (with --assets)")
    parser.add_argument("--report", type=Path, help="Also write the JSON report to this file")
    args = parser.parse_args(argv)
    archived = args.assets is not None or args.icon_data is not None
    if archived and (
        args.assets is None or args.icon_data is None
        or args.app or args.flutter_root or args.build_dir
    ):
        parser.error("Use --assets and --icon-data together, without release-web arguments")
    if not archived and (args.app is None or args.flutter_root is None):
        parser.error("Release-web verification needs --app and --flutter-root")
    try:
        if archived:
            report = verify(args.assets, json.loads(args.icon_data.read_text()))
        else:
            build_dir = args.build_dir or args.app / "build/web"
            constants, kernel = scan_kernel(args.app, build_dir, args.flutter_root)
            report = verify(build_dir / "assets", constants)
            report["kernel"] = str(kernel.resolve())
    except (
        OSError, ValueError, KeyError, TypeError, TTLibError,
        subprocess.CalledProcessError,
    ) as error:
        report = {"errors": [str(error)]}
    output = json.dumps(report, indent=2) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output)
    print(output, end="")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
