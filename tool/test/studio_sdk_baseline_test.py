"""Checks SDK/reference provenance, not application visual parity."""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StudioSdkBaselineTest(unittest.TestCase):
    def test_ci_matches_the_reviewed_reference_renderer(self):
        report = json.loads((ROOT / 'tool/baselines/flutter_3_47_2_golden_migration.json').read_text())
        workflow = (ROOT / '.github/workflows/ci.yaml').read_text()
        pinned = re.search(r'FLUTTER_VERSION:\s*"([^"]+)"', workflow)
        self.assertIsNotNone(pinned)
        self.assertEqual(pinned.group(1), report['flutter'])

    def test_only_exact_reviewed_references_are_migrated(self):
        report = json.loads((ROOT / 'tool/baselines/flutter_3_47_2_golden_migration.json').read_text())
        fixtures = report['fixtures']
        self.assertEqual(len(fixtures), 18)
        self.assertEqual(len({item['reference'] for item in fixtures}), 18)
        self.assertEqual(report['golden_comparison_tolerance'], 0)
        for item in fixtures:
            path = Path(item['reference'])
            self.assertFalse(path.is_absolute())
            self.assertNotIn('..', path.parts)
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(),
                             item['accepted_sha256'])
            self.assertEqual(item['outside_rounded_edges'], [])


if __name__ == '__main__':
    unittest.main()
