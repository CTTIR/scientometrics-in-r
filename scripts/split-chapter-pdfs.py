#!/usr/bin/env python3
"""Split chapter downloads from the complete PDF using its real bookmarks."""
import argparse
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit
from pypdf import PdfReader, PdfWriter

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(); self.title = ''; self.in_title = False; self.source = None
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'title': self.in_title = True
        if a.get('id') == 'book-source':
            match = re.search(r'/blob/[^/]+/(.+\.Rmd)$', a.get('href', ''))
            if match: self.source = unquote(match[1])
    def handle_endtag(self, tag):
        if tag == 'title': self.in_title = False
    def handle_data(self, data):
        if self.in_title: self.title += data

def normalize(title):
    title = title.split(' | ')[0].strip().lower()
    title = title.translate(str.maketrans({'’': "'", '‘': "'", '“': '"', '”': '"'}))
    title = re.sub(r'^(?:(?:chapter|appendix)\s+)?(?:\d+(?:\.\d+)*|[a-qs-z])\s*[.:—–-]?\s+', '', title)
    return re.sub(r'\s+', ' ', title).strip()

def split(root, name):
    reader = PdfReader(root / (name + '.pdf'))
    if not len(reader.pages): raise ValueError('Whole-book PDF has no pages')
    destinations = []
    def walk(outline, depth=0):
        for item in outline:
            if isinstance(item, list): walk(item, depth + 1)
            else:
                page = reader.get_destination_page_number(item)
                if page is not None and page >= 0:
                    destinations.append((normalize(item.title), page, depth))
    walk(reader.outline)
    html = [(file, Page(file.read_text())) for file in root.glob('*.html') if file.name != '404.html']
    matches = []
    for file, page in html:
        candidates = {(number, depth) for title, number, depth in destinations if title == normalize(page.title)}
        if candidates:
            shallowest = min(depth for _, depth in candidates)
            candidates = {(number, depth) for number, depth in candidates if depth == shallowest}
        if len(candidates) > 1:
            # Pandoc suffixes repeated heading slugs in document order.
            suffix = re.search(r"-(\d+)$", file.stem)
            if suffix and int(suffix[1]) < len(candidates):
                candidates = {sorted(candidates)[int(suffix[1])]}
        if len(candidates) == 1:
            number, depth = candidates.pop()
            matches.append((file, page, number, depth))
    if not matches: raise ValueError('No HTML chapter titles match PDF bookmarks')
    destination = root / 'pdf-chapters'; destination.mkdir(exist_ok=True)
    for file, page, start, depth in matches:
        end = min([p for _, p, d in destinations if p > start and d <= depth] + [len(reader.pages)])
        writer = PdfWriter()
        for number in range(start, end): writer.add_page(reader.pages[number])
        writer.add_metadata({'/Title': page.title.split(' | ')[0], '/Author': 'R. Heller'})
        names = {file.stem}
        if page.source: names.add(Path(page.source).stem)
        for stem in names:
            output = destination / (stem + '.pdf')
            with output.open('wb') as stream: writer.write(stream)
            assert len(PdfReader(output).pages) == end - start
    print(f'Created and reopened downloads for {len(matches)} HTML chapters')
    return len(matches)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path, nargs='?', default=Path('docs'))
    parser.add_argument('--book', default=Path.cwd().name)
    args = parser.parse_args(); split(args.root, args.book)
