"""Extract the reviewed changelog section for an existing stable release tag."""

import argparse
import re
from pathlib import Path


def release_notes(tag: str, changelog: str) -> str:
    if not re.fullmatch(r"v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", tag):
        raise ValueError("expected a stable version tag such as v0.1.0 (no leading zeroes)")
    headings = list(re.finditer(r"^## \[([^\]\n]+)\][^\n]*$", changelog, re.MULTILINE))
    matches = [i for i, heading in enumerate(headings) if heading[1] == tag[1:]]
    if len(matches) != 1:
        raise ValueError(f"CHANGELOG.md must contain exactly one '## [{tag[1:]}]' section")
    index = matches[0]
    start = headings[index].end()
    end = headings[index + 1].start() if index + 1 < len(headings) else len(changelog)
    notes = changelog[start:end].strip()
    if not notes:
        raise ValueError("the release changelog section must not be empty")
    return notes + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("changelog", nargs="?", type=Path, default=Path("CHANGELOG.md"))
    args = parser.parse_args()
    try:
        notes = release_notes(args.tag, args.changelog.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(notes, end="")


if __name__ == "__main__":
    main()
