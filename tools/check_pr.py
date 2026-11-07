"""Check a pull request body against the GunFare contribution rules.

The check enforces the mechanical ASD-STE100 limits that a program can test.
A reviewer must still confirm the approved STE dictionary.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = ("Summary", "Test", "Screenshots", "Diagram", "Table")
PLACEHOLDER = "REPLACE_THIS"
NOT_APPLICABLE = "Not applicable."
MAX_WORDS = 25
BANNED = {
    "very",
    "just",
    "really",
    "actually",
    "basically",
    "simply",
    "please",
    "sorry",
    "obviously",
}
CONTRACTIONS = re.compile(
    r"\b(?:it's|don't|can't|won't|isn't|aren't|wasn't|weren't|hasn't|haven't|"
    r"hadn't|doesn't|didn't|couldn't|shouldn't|wouldn't|that's|there's|they're|"
    r"we're|you're|i'm|let's|who's|what's|they're)\b",
    re.IGNORECASE,
)
IMAGE = re.compile(r"!\[[^\]]*\]\([^)]+\)|<img\s", re.IGNORECASE)
MERMAID = re.compile(r"```mermaid\b", re.IGNORECASE)
TABLE_ROW = re.compile(r"^\s*\|.+\|\s*$", re.MULTILINE)
VERSION_TOKEN = re.compile(r"\d+(?:\.\d+)+")

SCREEN_PREFIXES = (
    "scripts/ui/",
    "scripts/player/hud.gd",
    "scripts/player/viewmodel.gd",
    "assets/textures/",
    "assets/shaders/",
)
SCREEN_SUFFIXES = (".tscn", ".gdshader")
DIAGRAM_PREFIXES = (
    "scripts/autoload/",
    "scripts/match/",
    "scripts/maps/",
    "scripts/streaks/",
    "project.godot",
)
TABLE_PREFIXES = ("scripts/data/",)


def needs_screenshot(path: str) -> bool:
    normal = path.replace("\\", "/")
    if normal.endswith(SCREEN_SUFFIXES):
        return True
    return normal.startswith(SCREEN_PREFIXES)


def needs_diagram(path: str) -> bool:
    normal = path.replace("\\", "/")
    return normal == "project.godot" or normal.startswith(DIAGRAM_PREFIXES)


def needs_table(path: str) -> bool:
    return path.replace("\\", "/").startswith(TABLE_PREFIXES)


def parse_sections(body: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    current = ""
    lines: list[str] = []
    for line in body.splitlines():
        if line.startswith("## "):
            if current:
                sections[current] = "\n".join(lines).strip()
            current = line[3:].strip()
            lines = []
        else:
            lines.append(line)
    if current:
        sections[current] = "\n".join(lines).strip()
    return sections


def prose_without_code(text: str) -> str:
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)
    text = re.sub(r"`[^`]+`", " ", text)
    text = IMAGE.sub(" ", text)
    text = re.sub(r"\[[^\]]+\]\([^)]+\)", " ", text)
    return text


def sentences(text: str) -> list[str]:
    protected = VERSION_TOKEN.sub(lambda m: m.group(0).replace(".", "#"), text)
    parts = re.split(r"(?<=[.!?])\s+", protected.strip())
    return [part.replace("#", ".").strip() for part in parts if part.strip()]


def word_count(sentence: str) -> int:
    return len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'#.+-]*", sentence))


def check_ste(text: str, label: str) -> list[str]:
    errors: list[str] = []
    prose = prose_without_code(text)
    if ";" in prose:
        errors.append(f"{label} contains a semicolon. ASD-STE100 does not allow a semicolon.")
    if CONTRACTIONS.search(prose):
        errors.append(f"{label} contains a contraction. Write the full words.")
    for word in re.findall(r"[A-Za-z']+", prose.lower()):
        if word in BANNED:
            errors.append(f"{label} uses '{word}'. Remove that word.")
    for sentence in sentences(prose):
        count = word_count(sentence)
        if count > MAX_WORDS:
            errors.append(
                f"{label} has a sentence of {count} words. Use a maximum of {MAX_WORDS} words."
            )
    return errors


def check_body(body: str, files: list[str]) -> list[str]:
    errors: list[str] = []
    sections = parse_sections(body)
    for name in REQUIRED_SECTIONS:
        if name not in sections:
            errors.append(f"The pull request does not have a {name} section.")
    if errors:
        return errors
    for name in ("Summary", "Test"):
        if PLACEHOLDER in sections[name] or not sections[name].strip():
            errors.append(f"Replace the {name} placeholder with ASD-STE100 text.")
        else:
            errors.extend(check_ste(sections[name], name))
    screen = any(needs_screenshot(path) for path in files)
    diagram = any(needs_diagram(path) for path in files)
    table = any(needs_table(path) for path in files)
    errors.extend(_check_evidence("Screenshots", sections["Screenshots"], screen, IMAGE.search(sections["Screenshots"]) is not None, "Add a screenshot image."))
    diagram_ok = MERMAID.search(sections["Diagram"]) or IMAGE.search(sections["Diagram"])
    errors.extend(_check_evidence("Diagram", sections["Diagram"], diagram, bool(diagram_ok), "Add a mermaid diagram or a diagram image."))
    table_ok = TABLE_ROW.search(sections["Table"]) is not None
    errors.extend(_check_evidence("Table", sections["Table"], table, table_ok, "Add a Markdown table."))
    return errors


def _check_evidence(name: str, text: str, required: bool, present: bool, demand: str) -> list[str]:
    if required:
        if text.strip() == NOT_APPLICABLE or not present:
            return [f"The {name} section is required for these files. {demand}"]
        return []
    if text.strip() != NOT_APPLICABLE:
        return [f"The {name} section is not required. Write '{NOT_APPLICABLE}' or remove the extra files from the change."]
    return []


def self_test() -> list[str]:
    failures: list[str] = []

    def expect(errors: list[str], needle: str, case: str) -> None:
        if not any(needle in error for error in errors):
            failures.append(f"{case} did not report '{needle}'. Got: {errors}")

    good = """## Summary

The menu shows the new version. The player can install that version.

## Test

1. Start a release build.
2. Confirm that the menu shows the install control.

## Screenshots

Not applicable.

## Diagram

Not applicable.

## Table

Not applicable.
"""
    errors = check_body(good, ["README.md"])
    if errors:
        failures.append(f"Valid text failed: {errors}")
    screen_errors = check_body(good, ["scripts/ui/main_menu.gd"])
    expect(screen_errors, "Screenshots", "screen requirement")
    data_errors = check_body(good, ["scripts/data/weapon_data.gd"])
    expect(data_errors, "Table", "table requirement")
    diagram_body = good.replace("## Diagram\n\nNot applicable.", "## Diagram\n\n```mermaid\nflowchart TD\n  aNode[Start] --> bNode[Stop]\n```")
    diagram_errors = check_body(diagram_body, ["scripts/autoload/game.gd"])
    if diagram_errors:
        failures.append(f"Diagram text failed: {diagram_errors}")
    long_sentence = " ".join(["word"] * 30) + "."
    long_body = good.replace("The menu shows the new version. The player can install that version.", long_sentence)
    expect(check_body(long_body, ["README.md"]), "maximum", "sentence length")
    contraction = good.replace("The menu shows the new version.", "The menu doesn't show the version.")
    expect(check_body(contraction, ["README.md"]), "contraction", "contraction")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--body-file")
    parser.add_argument("--event-file")
    parser.add_argument("--files-file")
    args = parser.parse_args()
    if args.self_test:
        failures = self_test()
        if failures:
            print("\n".join(failures))
            return 1
        print("check_pr self-test passed")
        return 0
    if args.event_file:
        payload = json.loads(Path(args.event_file).read_text(encoding="utf-8"))
        body = payload.get("pull_request", {}).get("body") or ""
    elif args.body_file:
        body = Path(args.body_file).read_text(encoding="utf-8")
    else:
        print("Provide --self-test, --event-file, or --body-file.")
        return 1
    files = []
    if args.files_file:
        files = [line.strip() for line in Path(args.files_file).read_text(encoding="utf-8").splitlines() if line.strip()]
    errors = check_body(body, files)
    if errors:
        print("Pull request check failed.")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Pull request check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
