#!/usr/bin/env python3
"""Check supported local Markdown link targets exist, without validating anchors or external URLs."""
from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

LINK = re.compile(r"!?\[[^\]]*\]\(([^)]*)\)")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")


def markdown_files(root: Path) -> list[Path]:
    return sorted(
        path for path in root.rglob("*.md")
        if not any(part in {".git", ".build", ".swiftpm", "DerivedData"} for part in path.parts)
    )


def links_outside_fences(text: str) -> list[str]:
    links: list[str] = []
    fence: tuple[str, int] | None = None
    for line in text.splitlines():
        match = FENCE.match(line)
        if fence is not None:
            if match:
                marker, remainder = match.groups()
                if marker[0] == fence[0] and len(marker) >= fence[1] and not remainder.strip():
                    fence = None
            continue
        if match:
            marker, _ = match.groups()
            fence = (marker[0], len(marker))
            continue
        links.extend(link_destination(match.group(1)) for match in LINK.finditer(line))
    return links


def link_destination(raw: str) -> str:
    """Extract the supported inline destination, retaining spaces inside angle brackets."""
    value = raw.strip()
    if value.startswith("<"):
        closing = value.find(">", 1)
        return value[1:closing] if closing >= 0 else value[1:]
    return value.split(maxsplit=1)[0] if value else ""


def validate(root: Path, files: list[Path] | None = None) -> list[str]:
    failures: list[str] = []
    for source in files or markdown_files(root):
        for raw in links_outside_fences(source.read_text(encoding="utf-8")):
            if not raw or raw.startswith("#") or raw.startswith("//") or SCHEME.match(raw):
                continue
            path_text = unquote(urlsplit(raw).path)
            if not path_text:
                continue
            target = (root / path_text.lstrip("/")) if raw.startswith("/") else (source.parent / path_text)
            if not target.resolve().exists():
                failures.append(f"{source.relative_to(root)}: missing local link {raw}")
    return failures


def self_test() -> bool:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "docs").mkdir()
        (root / "docs" / "target.md").write_text("# Target\n", encoding="utf-8")
        (root / "docs" / "with space.md").write_text("# Spaced target\n", encoding="utf-8")
        good = root / "good.md"
        good.write_text(
            "[relative](docs/target.md?view=1#target) [anchor](#local) "
            "[external](https://example.invalid/no-request) "
            "[spaced](<docs/with space.md>) [empty]() [blank](   )\n"
            "````md\n[ignored](missing-in-fence.md)\n```\n"
            "[still ignored](also-missing.md)\n````\n",
            encoding="utf-8",
        )
        bad = root / "bad.md"
        bad.write_text(
            "[broken](docs/missing.md#section) [spaced missing](<docs/not here.md>)\n",
            encoding="utf-8",
        )
        return validate(root, [good]) == [] and len(validate(root, [bad])) == 2


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    if args.self_test and not self_test():
        print("markdown link validator self-test failed", file=sys.stderr)
        return 2
    failures = validate(args.root.resolve())
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"validated local Markdown links in {len(markdown_files(args.root.resolve()))} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
