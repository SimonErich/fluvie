import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("site_links", Path(__file__).with_name("check_site_links.py"))
site_links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(site_links)


class SiteLinksTest(unittest.TestCase):
    def test_marketing_llms_targets_resolve_against_docs_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            site = root / "site"
            docs = root / "docs"
            site.mkdir()
            page = docs / "guides" / "hello" / "index.html"
            page.parent.mkdir(parents=True)
            page.write_text('<h1 id="first">Hello</h1>')
            (site / "index.html").write_text('<a href="/media/source.dart">Source</a>')
            (site / "media").mkdir()
            (site / "media" / "source.dart").write_text('Video build() => video;')
            (site / "llms.txt").write_text('[Hello](https://docs.fluvie.dev/guides/hello/#first)')
            count, errors = site_links.check(site, documentation_root=docs)
            self.assertEqual(errors, [])
            self.assertEqual(count, 2)
            page.write_text('<h1 id="changed">Hello</h1>')
            self.assertIn("missing published anchor", "\n".join(site_links.check(site, documentation_root=docs)[1]))

    def test_local_video_source_and_poster_must_exist(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "llms.txt").write_text('')
            (root / "index.html").write_text('<video poster="/media/poster.png"><source src="/media/video.mp4"></video>')
            _, errors = site_links.check(root)
            self.assertIn("poster.png", "\n".join(errors))
            self.assertIn("video.mp4", "\n".join(errors))


if __name__ == "__main__":
    unittest.main()
