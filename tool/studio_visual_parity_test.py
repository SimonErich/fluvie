"""Independent fixtures for the Studio screenshot comparison contract."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

from studio_visual_parity import Region, compare, passes


class StudioVisualParityTest(unittest.TestCase):
    def _run_cli(self, reference, actual, output, *options):
        return subprocess.run(
            [sys.executable, str(Path(__file__).with_name("studio_visual_parity.py")),
             str(reference), str(actual), "--out", str(output), *options],
            capture_output=True, text=True, check=False,
        )

    def test_identical_images_pass_exact_parity(self):
        reference = Image.new("RGBA", (16, 16), (22, 25, 32, 255))
        report = compare(reference, reference.copy())
        self.assertEqual(report["whole"]["changed_ratio"], 0)
        self.assertEqual(report["whole"]["mae"], 0)
        self.assertEqual(report["whole"]["ssim"], 1)
        self.assertTrue(passes(report))

    def test_changed_pixel_fails_without_masking_small_regressions(self):
        reference = Image.new("RGBA", (16, 16), (0, 0, 0, 255))
        actual = reference.copy()
        actual.putpixel((3, 4), (255, 0, 0, 255))
        report = compare(reference, actual)
        self.assertEqual(report["whole"]["changed_ratio"], 1 / 256)
        self.assertAlmostEqual(report["whole"]["mae"], 1 / 1024)
        self.assertEqual(report["whole"]["max_channel_delta"], 255)
        self.assertFalse(passes(report))

    def test_black_white_fixture_has_independently_known_error(self):
        reference = Image.new("RGBA", (8, 8), (0, 0, 0, 255))
        actual = Image.new("RGBA", (8, 8), (255, 255, 255, 255))
        whole = compare(reference, actual)["whole"]
        self.assertEqual(whole["changed_ratio"], 1)
        self.assertEqual(whole["mae"], 0.75)
        self.assertAlmostEqual(whole["rmse"], 0.8660254037844386)
        self.assertAlmostEqual(whole["ssim"], 0.0000999900009999)

    def test_alpha_changes_are_visible_even_when_rgb_matches(self):
        reference = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        actual = Image.new("RGBA", (8, 8), (0, 0, 0, 255))
        report = compare(reference, actual)
        self.assertEqual(report["whole"]["mae"], 0.25)
        self.assertFalse(passes(report))

    def test_dimension_changes_are_errors_and_never_resized(self):
        with self.assertRaisesRegex(ValueError, "dimensions"):
            compare(Image.new("RGB", (8, 8)), Image.new("RGB", (9, 8)))

    def test_regions_localize_error_and_do_not_hide_whole_image(self):
        reference = Image.new("RGBA", (16, 8), (0, 0, 0, 255))
        actual = reference.copy()
        actual.putpixel((15, 7), (255, 255, 255, 255))
        report = compare(reference, actual, [Region("rail", 0, 0, 8, 8)])
        self.assertEqual(report["regions"]["rail"]["changed_ratio"], 0)
        self.assertFalse(passes(report))

    def test_regions_must_be_named_unique_positive_and_inside_image(self):
        reference = Image.new("RGBA", (8, 8))
        for regions in [
            [Region("outside", 0, 0, 9, 8)],
            [Region("negative", -1, 0, 8, 8)],
            [Region("empty", 0, 0, 0, 8)],
            [Region("", 0, 0, 8, 8)],
            [Region("rail", 0, 0, 8, 8), Region("rail", 0, 0, 8, 8)],
        ]:
            with self.subTest(regions=regions), self.assertRaises(ValueError):
                compare(reference, reference, regions)

    def test_tolerances_are_explicit_and_still_apply_to_each_region(self):
        reference = Image.new("RGBA", (16, 8), (0, 0, 0, 255))
        actual = reference.copy()
        actual.putpixel((0, 0), (8, 8, 8, 255))
        report = compare(reference, actual, [Region("pixel", 0, 0, 1, 1)])
        self.assertFalse(passes(report, max_changed_ratio=0.1, max_mae=0.1, min_ssim=0))
        with self.assertRaises(ValueError):
            passes(report, max_changed_ratio=1.01)

    def test_cli_success_has_hashes_and_all_review_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output = root / "source.png", root / "review"
            Image.new("RGBA", (8, 8), (20, 30, 40, 255)).save(source)
            result = self._run_cli(source, source, output)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads((output / "report.json").read_text())
            self.assertTrue(report["passed"])
            self.assertTrue(report["exact_parity"])
            self.assertEqual(report["sources"]["actual"]["sha256"], hashlib.sha256(source.read_bytes()).hexdigest())
            for name in ("diff.png", "heatmap.png", "side-by-side.png"):
                with Image.open(output / name) as artifact:
                    artifact.load()

    def test_cli_mismatch_and_input_failure_replace_stale_pass_reports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, actual, output = root / "source.png", root / "actual.png", root / "review"
            Image.new("RGB", (8, 8), "black").save(source)
            self.assertEqual(self._run_cli(source, source, output).returncode, 0)
            Image.new("RGB", (8, 8), "white").save(actual)
            self.assertEqual(self._run_cli(source, actual, output).returncode, 1)
            self.assertFalse(json.loads((output / "report.json").read_text())["passed"])
            self.assertEqual(self._run_cli(source, source, output).returncode, 0)
            Image.new("RGB", (9, 8), "black").save(actual)
            self.assertEqual(self._run_cli(source, actual, output).returncode, 2)
            failed = json.loads((output / "report.json").read_text())
            self.assertFalse(failed["passed"])
            self.assertIn("dimensions", failed["error"])

    def test_cli_never_overwrites_input_screenshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "diff.png"
            Image.new("RGB", (8, 8), "black").save(source)
            before = source.read_bytes()
            self.assertEqual(self._run_cli(source, source, root).returncode, 2)
            self.assertEqual(source.read_bytes(), before)

    def test_cli_never_overwrites_input_region_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, regions = root / "source.png", root / "report.json"
            Image.new("RGB", (8, 8), "black").save(source)
            regions.write_text('[{"name":"rail","x":0,"y":0,"width":8,"height":8}]')
            before = regions.read_bytes()
            self.assertEqual(self._run_cli(source, source, root, "--regions", str(regions)).returncode, 2)
            self.assertEqual(regions.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
