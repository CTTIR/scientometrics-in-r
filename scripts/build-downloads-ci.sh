#!/usr/bin/env bash
set -euo pipefail
root="$1"
book="$2"
site="$3"
python3 -m venv "$RUNNER_TEMP/book-download-python"
"$RUNNER_TEMP/book-download-python/bin/pip" install beautifulsoup4==4.15.0 lxml==6.1.3 pypdf==6.21.4
npm install --prefix "$RUNNER_TEMP/book-download-node" --no-audit --no-fund playwright@1.63.0
"$RUNNER_TEMP/book-download-node/node_modules/.bin/playwright" install --with-deps chromium
export NODE_PATH="$RUNNER_TEMP/book-download-node/node_modules"
"$RUNNER_TEMP/book-download-python/bin/python" scripts/build-book-downloads.py "$root" --book "$book" --site "$site"
"$RUNNER_TEMP/book-download-python/bin/python" scripts/check-download-surface.py "$root"
python3 scripts/check-no-counting-pixels.py .
curl --fail --location --retry 3 https://github.com/w3c/epubcheck/releases/download/v5.4.0/epubcheck-5.4.0.zip --output "$RUNNER_TEMP/book-epubcheck.zip"
printf '%s  %s\n' '33350c61038e71dfb3d45a76aed04bf5481e6d5500cb780f6e98db8bbd15a28c' "$RUNNER_TEMP/book-epubcheck.zip" | sha256sum --check -
python3 -m zipfile -e "$RUNNER_TEMP/book-epubcheck.zip" "$RUNNER_TEMP/book-epubcheck"
python3 scripts/check-download-epubs.py "$root" "$RUNNER_TEMP/book-epubcheck/epubcheck-5.4.0/epubcheck.jar"
