#!/usr/bin/env python3
"""Check local Markdown targets and optionally verify external URLs."""

from __future__ import annotations

import argparse
import concurrent.futures
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
ALLOWED_EXTERNAL_STATUS = {401, 403, 429}


def markdown_links(root: pathlib.Path):
    for document in sorted(root.rglob("*.md")):
        if ".git" in document.parts:
            continue
        in_fence = False
        for line in document.read_text(encoding="utf-8").splitlines():
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for match in LINK_RE.finditer(line):
                target = match.group(1).strip().split(maxsplit=1)[0].strip("<>")
                yield document, target


def check_external(url: str) -> str | None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "hashicorp-agent-skills-link-check/1.0"},
        method="HEAD",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            if response.status < 400:
                return None
            return f"HTTP {response.status}"
    except urllib.error.HTTPError as error:
        if error.code in ALLOWED_EXTERNAL_STATUS:
            return None
        return f"HTTP {error.code}"
    except (urllib.error.URLError, TimeoutError) as error:
        return str(error)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--local-only", action="store_true")
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent
    failures: list[str] = []
    external_sources: dict[str, set[pathlib.Path]] = {}

    for document, target in markdown_links(root):
        parsed = urllib.parse.urlsplit(target)
        if parsed.scheme in {"http", "https"}:
            external_sources.setdefault(target, set()).add(document)
            continue
        if parsed.scheme or target.startswith("#"):
            continue
        path_text = urllib.parse.unquote(parsed.path)
        if not path_text:
            continue
        resolved = (document.parent / path_text).resolve()
        if not resolved.exists():
            failures.append(f"{document.relative_to(root)} -> {target}")

    if not args.local_only:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            results = executor.map(check_external, external_sources)
            for url, problem in zip(external_sources, results):
                if problem:
                    sources = ", ".join(
                        str(path.relative_to(root))
                        for path in sorted(external_sources[url])
                    )
                    failures.append(f"{sources} -> {url} ({problem})")

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}")
        print(f"Link check failed with {len(failures)} error(s).")
        return 1

    scope = "local" if args.local_only else "local and external"
    print(f"Link check passed for {scope} Markdown targets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
