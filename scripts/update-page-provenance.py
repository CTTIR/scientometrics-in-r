#!/usr/bin/env python3
"""Refresh chapter provenance from Git history before rendering any format.

Dates describe committed source revisions, not the render. Provenance-only
commits are excluded when identifying the last content change. Full Git history is required for creation dates.

The last change is searched along the first-parent line, so a merge that brings
new content counts as the change it makes. When a merge only adopts a branch's
version of a page, the search continues on that branch to credit the commit that
wrote it.
"""
from datetime import date
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
NOTE = re.compile(r"\n\n<!-- page-provenance:start -->.*?<!-- page-provenance:end -->\n", re.S)

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True, stderr=subprocess.PIPE).strip()

def clean(text):
    return NOTE.sub("\n", text)

def content(text):
    text = clean(text).strip()
    if text.startswith("---\n"):
        parts = text.split("---", 2)
        if len(parts) == 3:
            parts[1] = re.sub(r"^(?:date|date-modified):.*\n", "", parts[1], flags=re.M)
            text = "---".join(parts)
    return text

def revision(commit, relative):
    try:
        return content(git("show", commit + ":" + relative))
    except subprocess.CalledProcessError:
        return None  # Absent in this revision, e.g. before a rename.

def last_change(relative, start="HEAD"):
    for row in git("log", "--first-parent", "--format=%H %as %P", start, "--", relative).splitlines():
        commit, day, *parents = row.split()
        current = revision(commit, relative)
        if current is not None and parents and current == revision(parents[0], relative):
            continue  # Only the page note or its date changed.
        for branch in parents[1:]:
            if current is not None and current == revision(branch, relative):
                return last_change(relative, branch)
        return day
    return None

def source_dates(relative):
    dates = git("log", "--follow", "--format=%as", "--", relative).splitlines()
    first = dates[-1] if dates else date.today().isoformat()
    last = last_change(relative) or first
    return first, max(first, last)

def refresh():
    if git("rev-parse", "--is-shallow-repository") == "true":
        raise SystemExit("Provenance needs full history: git fetch --unshallow")
    count = 0
    for relative in git("ls-files", "*.Rmd", "*.qmd").splitlines():
        if relative.startswith(("drafts/", "renv/")) or "TEMPLATE" in relative:
            continue
        path = ROOT / relative
        text = path.read_text()
        body = clean(text)
        offset = 0
        fenced = False
        frontmatter = body.startswith("---\n")
        heading = None
        for line in body.splitlines(True):
            if frontmatter:
                if offset and line.strip() in ("---", "..."):
                    frontmatter = False
            elif re.match(r"^\s*(`{3,}|~{3,})", line):
                fenced = not fenced
            elif not fenced and re.match(r"^# (?!\(PART\)|\(APPENDIX\))", line):
                heading = re.search(r"^# .+$", body[offset:], re.M)
                heading_end = offset + heading.end()
                break
            elif not fenced and line.startswith("`r if (knitr::is_html_output()) '# References"):
                heading = True
                heading_end = offset + len(line.rstrip("\n"))
                break
            offset += len(line)
        if not heading:
            continue
        first, last = source_dates(relative)
        note =("\n<!-- page-provenance:start -->\n"
                "::: {.page-provenance}\n"
                f"*R. Heller · Date: {first} · Last changed: {last}*\n"
                ":::\n<!-- page-provenance:end -->\n")
        updated = body[:heading_end] + "\n" + note + body[heading_end:]
        # Keep the insertion idempotent without changing surrounding prose.
        updated = re.sub(r"(<!-- page-provenance:end -->)\n{3,}", r"\1\n\n", updated)
        if updated.startswith("---\n"):
            parts = updated.split("---", 2)
            if len(parts) == 3:
                parts[1] = re.sub(r"^(date(?:-modified)?):.*$", lambda m: m[1] + ': "' + (max(git("log", "--format=%as").splitlines()) if relative in ("index.Rmd", "index.qmd") and m[1] == "date" else last) + '"', parts[1], flags=re.M)
                updated = "---".join(parts)
        if updated != text:
            path.write_text(updated)
        count += 1
    book_dates = git("log", "--format=%as").splitlines()
    caption = f"R. Heller · Date: {min(book_dates)} · Last changed: {max(book_dates)}"
    footer = (r"\scriptsize " + caption + r"\hfill\thepage")
    tex = "\n".join([
        r"\usepackage{fancyhdr}", r"\setlength{\headheight}{25pt}",
        r"\pagestyle{fancy}", r"\fancyhead{}", r"\fancyhead[C]{\small\nouppercase{\leftmark}}", r"\fancyfoot{}",
        r"\fancyfoot[C]{" + footer + "}",
        r"\fancypagestyle{plain}{\fancyhf{}\renewcommand{\headrulewidth}{0pt}\fancyfoot[C]{" + footer + "}}", ""])
    destination = ROOT / "style" / "provenance.tex"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(tex)
    print(f"Provenance refreshed for {count} chapter sources")

if __name__ == "__main__":
    refresh()
