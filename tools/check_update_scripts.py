"""Confirm that the install scripts and the game copy use the same marker."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PAIRS = (
    ("tools/apply_update.ps1", "GUNFARE_UPDATE_SCRIPT_WINDOWS"),
    ("tools/apply_update.sh", "GUNFARE_UPDATE_SCRIPT_UNIX"),
)


def main() -> int:
    game = (ROOT / "scripts/autoload/update_service.gd").read_text(encoding="utf-8")
    failed = False
    for relative, marker in PAIRS:
        script = (ROOT / relative).read_text(encoding="utf-8")
        if marker not in script:
            print(f"{relative} does not contain {marker}")
            failed = True
        if marker not in game:
            print(f"update_service.gd does not contain {marker}")
            failed = True
        embedded = _embedded(game, marker)
        if embedded is None:
            print(f"update_service.gd does not embed {relative}")
            failed = True
            continue
        if _norm(embedded) != _norm(script):
            print(f"{relative} does not match the script in update_service.gd")
            failed = True
    if failed:
        return 1
    print("update scripts match")
    return 0


def _embedded(game: str, marker: str) -> str | None:
    needle = '"""'
    pos = 0
    while True:
        start = game.find(needle, pos)
        if start < 0:
            return None
        start += len(needle)
        end = game.find(needle, start)
        if end < 0:
            return None
        chunk = game[start:end]
        if marker in chunk:
            return chunk
        pos = end + len(needle)


def _norm(text: str) -> str:
    return text.replace("\r\n", "\n").strip()


if __name__ == "__main__":
    sys.exit(main())
