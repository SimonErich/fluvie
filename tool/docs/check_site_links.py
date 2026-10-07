#!/usr/bin/env python3
"""Check built local documentation routes and canonical edit links offline."""
import argparse
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ("id", "name") and value:
                self.ids.add(value)
            if key in ("href", "src", "poster") and value:
                self.links.append(value)


def check(root, documentation_root=None):
    root = Path(root).resolve()
    documentation_root = Path(documentation_root).resolve() if documentation_root else root
    repository = Path(__file__).resolve().parents[2]
    errors = []
    count = 0
    parsed = {}
    def page_links(page):
        page = page.resolve()
        if page not in parsed:
            parser = Links()
            parser.feed(page.read_text())
            parsed[page] = parser
        return parsed[page]
    for page in sorted(root.rglob("*.html")):
        parser = page_links(page)
        for href in parser.links:
            url = urlsplit(href)
            edit_prefix = "https://github.com/SimonErich/fluvie/edit/main/"
            if href.startswith(edit_prefix):
                source = repository / unquote(url.path.split("/edit/main/", 1)[1])
                if not source.is_file():
                    errors.append(f"{page.relative_to(root)}: edit source does not exist: {href}")
            if url.scheme or url.netloc:
                continue
            count += 1
            path = unquote(url.path)
            target = page if not path else (root / path.lstrip("/") if path.startswith("/") else page.parent / path)
            if target.is_dir():
                target = target / "index.html"
            if not target.is_file():
                errors.append(f"{page.relative_to(root)}: missing local target: {href}")
            elif url.fragment and target.suffix == ".html" and not url.fragment.startswith(":~:text="):
                anchor = unquote(url.fragment)
                if anchor not in page_links(target).ids:
                    errors.append(f"{page.relative_to(root)}: missing local anchor: {href}")
    llms = root / "llms.txt"
    if not llms.is_file():
        errors.append("llms.txt: missing generated documentation index")
    else:
        for href in re.findall(r"\]\((https://docs\.fluvie\.dev/[^)\s]*)\)", llms.read_text()):
            count += 1
            url = urlsplit(href)
            target = documentation_root / unquote(url.path).lstrip("/")
            if target.is_dir():
                target = target / "index.html"
            if not target.is_file():
                errors.append(f"llms.txt: missing published target: {href}")
            elif url.fragment and target.suffix == ".html" and unquote(url.fragment) not in page_links(target).ids:
                errors.append(f"llms.txt: missing published anchor: {href}")
    return count, errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", help="Astro's built dist directory")
    parser.add_argument("--docs-root", help="Built documentation routes used by a marketing llms.txt")
    args = parser.parse_args()
    count, errors = check(args.directory, documentation_root=args.docs_root)
    if not list(Path(args.directory).rglob("*.html")):
        parser.error("No built HTML pages found; build the site first")
    print(f"Checked {count} local links: {len(errors)} missing targets")
    for error in errors:
        print(error)
    raise SystemExit(bool(errors))
