"""Exercise actual generated font files, including missing/empty glyph failures."""

import json
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

from verify_icon_fonts import main, required_icons, verify


class IconFontVerificationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.assets = Path(self.temp.name)
        self.constants = {
            "constantInstances": [{"fontFamily": "Icons", "fontPackage": "test", "codePoint": 65.0}],
            "nonConstantLocations": [],
        }
        self.manifest = [{"family": "packages/test/Icons", "fonts": [{"asset": "icons.ttf"}]}]
        self.write_manifest()
        self.write_font()

    def write_manifest(self):
        (self.assets / "FontManifest.json").write_text(json.dumps(self.manifest))

    def write_font(self, *, empty=False, point=65):
        pen = TTGlyphPen(None)
        if not empty:
            pen.moveTo((0, 0))
            pen.lineTo((500, 0))
            pen.lineTo((250, 600))
            pen.closePath()
        font = FontBuilder(1000, isTTF=True)
        font.setupGlyphOrder([".notdef", "icon"])
        font.setupCharacterMap({point: "icon"})
        font.setupGlyf({".notdef": TTGlyphPen(None).glyph(), "icon": pen.glyph()})
        font.setupHorizontalMetrics({".notdef": (500, 0), "icon": (500, 0)})
        font.setupHorizontalHeader(ascent=800, descent=-200)
        font.setupNameTable({"familyName": "Icons", "styleName": "Regular", "uniqueFontIdentifier": "Icons", "fullName": "Icons", "psName": "Icons"})
        font.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
        font.setupPost()
        font.setupMaxp()
        font.save(self.assets / "icons.ttf")

    def test_package_font_visible_glyph_passes(self):
        result = verify(self.assets, self.constants)
        self.assertEqual(result["errors"], [])
        self.assertEqual(result["families"]["packages/test/Icons"]["verifiedGlyphOutlines"], 1)

    def test_missing_font_family_fails(self):
        self.manifest = []
        self.write_manifest()
        self.assertIn("Missing icon font family", verify(self.assets, self.constants)["errors"][0])

    def test_missing_cmap_entry_fails(self):
        self.write_font(point=66)
        self.assertIn("missing=[65]", verify(self.assets, self.constants)["errors"][0])

    def test_empty_outline_fails_even_with_valid_cmap(self):
        self.write_font(empty=True)
        self.assertIn("empty outlines=[65]", verify(self.assets, self.constants)["errors"][0])

    def test_dynamic_and_empty_scans_fail(self):
        with self.assertRaises(ValueError):
            required_icons({"constantInstances": [], "nonConstantLocations": ["dynamic.dart:1"]})
        with self.assertRaises(ValueError):
            required_icons({"constantInstances": [], "nonConstantLocations": []})

    def test_invalid_asset_cli_reports_failure(self):
        data = self.assets / "constants.json"
        data.write_text(json.dumps(self.constants))
        (self.assets / "icons.ttf").unlink()
        report = self.assets / "report.json"
        with redirect_stdout(io.StringIO()):
            status = main([
                "--assets", str(self.assets), "--icon-data", str(data),
                "--report", str(report),
            ])
        self.assertEqual(status, 1)
        self.assertTrue(json.loads(report.read_text())["errors"])


if __name__ == "__main__":
    unittest.main()
