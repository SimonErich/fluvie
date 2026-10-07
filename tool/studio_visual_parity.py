"""Compare Studio screenshots without resizing, masking or blessing differences.

Requires Pillow. Exact pixel parity is the default. A relaxed run records its
explicit thresholds in report.json; it is never described as exact parity.
"""

import argparse
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageEnhance


@dataclass(frozen=True)
class Region:
    name: str
    x: int
    y: int
    width: int
    height: int

    def box(self):
        return (self.x, self.y, self.x + self.width, self.y + self.height)


def _ssim(reference, actual):
    """Population SSIM over 8px luminance windows, weighted by window area."""
    reference, actual = reference.convert("L"), actual.convert("L")
    weighted = 0.0
    count = 0
    for y in range(0, reference.height, 8):
        for x in range(0, reference.width, 8):
            box = (x, y, min(x + 8, reference.width), min(y + 8, reference.height))
            left = reference.crop(box).tobytes()
            right = actual.crop(box).tobytes()
            n = len(left)
            a, b = sum(left) / n, sum(right) / n
            variance_a = sum((v - a) ** 2 for v in left) / n
            variance_b = sum((v - b) ** 2 for v in right) / n
            covariance = sum((v - a) * (w - b) for v, w in zip(left, right)) / n
            c1, c2 = 6.5025, 58.5225
            numerator = (2 * a * b + c1) * (2 * covariance + c2)
            denominator = (a * a + b * b + c1) * (variance_a + variance_b + c2)
            weighted += n * max(-1, min(1, numerator / denominator))
            count += n
    return weighted / count


def _metrics(reference, actual):
    delta = ImageChops.difference(reference, actual)
    histogram = delta.histogram()
    n = reference.width * reference.height
    absolute = sum((i % 256) * count for i, count in enumerate(histogram))
    squared = sum((i % 256) ** 2 * count for i, count in enumerate(histogram))
    maximum = max(i % 256 for i, count in enumerate(histogram) if count)
    channels = delta.split()
    magnitude = channels[0]
    for channel in channels[1:]:
        magnitude = ImageChops.lighter(magnitude, channel)
    magnitudes = magnitude.histogram()
    return {
        "pixels": n,
        "changed_ratio": 1 - magnitudes[0] / n,
        "significant_changed_ratio": sum(magnitudes[9:]) / n,
        "mae": absolute / (n * 4 * 255),
        "rmse": math.sqrt(squared / (n * 4)) / 255,
        "max_channel_delta": maximum,
        "ssim": _ssim(reference, actual),
    }


def compare(reference, actual, regions=()):
    if reference.size != actual.size:
        raise ValueError(f"Screenshot dimensions differ: {reference.size} != {actual.size}")
    if min(reference.size) <= 0:
        raise ValueError("Screenshot dimensions must be positive")
    names = set()
    for region in regions:
        coordinates = (region.x, region.y, region.width, region.height)
        if not region.name or region.name in names:
            raise ValueError("Regions must have unique nonempty names")
        if any(type(value) is not int for value in coordinates):
            raise ValueError("Region coordinates must be integer pixels")
        if min(region.x, region.y) < 0 or min(region.width, region.height) <= 0:
            raise ValueError(f"Invalid region: {region.name}")
        if region.x + region.width > reference.width or region.y + region.height > reference.height:
            raise ValueError(f"Region exceeds screenshot dimensions: {region.name}")
        names.add(region.name)
    reference, actual = reference.convert("RGBA"), actual.convert("RGBA")
    return {
        "width": reference.width,
        "height": reference.height,
        "whole": _metrics(reference, actual),
        "regions": {
            region.name: _metrics(reference.crop(region.box()), actual.crop(region.box()))
            for region in regions
        },
    }


def passes(report, *, max_changed_ratio=0, max_mae=0, min_ssim=1):
    if not all(0 <= value <= 1 for value in (max_changed_ratio, max_mae, min_ssim)):
        raise ValueError("Thresholds must be between zero and one")
    return all(
        metrics["changed_ratio"] <= max_changed_ratio
        and metrics["mae"] <= max_mae
        and metrics["ssim"] >= min_ssim
        for metrics in [report["whole"], *report["regions"].values()]
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("actual", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--regions", type=Path, help="JSON array of name/x/y/width/height objects")
    parser.add_argument("--max-changed-ratio", type=float, default=0)
    parser.add_argument("--max-mae", type=float, default=0)
    parser.add_argument("--min-ssim", type=float, default=1)
    args = parser.parse_args()
    thresholds = {
        "max_changed_ratio": args.max_changed_ratio,
        "max_mae": args.max_mae,
        "min_ssim": args.min_ssim,
    }
    safe_output = False
    try:
        sources = {args.reference.resolve(), args.actual.resolve()}
        if args.regions:
            sources.add(args.regions.resolve())
        outputs = [args.out / name for name in ("report.json", "diff.png", "heatmap.png", "side-by-side.png")]
        if any(output.resolve() in sources for output in outputs):
            raise ValueError("Output artifacts must not overwrite any input")
        args.out.mkdir(parents=True, exist_ok=True)
        safe_output = True
        (args.out / "report.json").write_text(json.dumps({"passed": False, "error": "Comparison has not completed"}) + "\n")
        regions = [Region(**value) for value in json.loads(args.regions.read_text())] if args.regions else []
        with Image.open(args.reference) as left, Image.open(args.actual) as right:
            reference, actual = left.convert("RGBA"), right.convert("RGBA")
        report = compare(reference, actual, regions)
        report["thresholds"] = thresholds
        report["passed"] = passes(report, **thresholds)
        report["exact_parity"] = report["whole"]["changed_ratio"] == 0
        report["sources"] = {
            key: {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            for key, path in (("reference", args.reference), ("actual", args.actual))
        }
        delta = ImageChops.difference(reference, actual)
        red, green, blue, alpha = delta.split()
        Image.merge("RGB", tuple(ImageChops.lighter(channel, alpha) for channel in (red, green, blue))).save(args.out / "diff.png")
        magnitude = delta.split()[0]
        for channel in delta.split()[1:]:
            magnitude = ImageChops.lighter(magnitude, channel)
        heat = ImageEnhance.Brightness(magnitude).enhance(4)
        Image.merge("RGB", (heat, Image.new("L", heat.size), Image.new("L", heat.size))).save(args.out / "heatmap.png")
        side = Image.new("RGBA", (reference.width * 2, reference.height))
        side.paste(reference, (0, 0))
        side.paste(actual, (reference.width, 0))
        side.save(args.out / "side-by-side.png")
        (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        sys.stdout.write(json.dumps({"passed": report["passed"], "exact_parity": report["exact_parity"], **report["whole"]}) + "\n")
        return 0 if report["passed"] else 1
    except (OSError, ValueError, TypeError) as error:
        if safe_output:
            (args.out / "report.json").write_text(json.dumps({"passed": False, "error": str(error)}) + "\n")
        sys.stderr.write(f"Visual comparison failed: {error}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main())
