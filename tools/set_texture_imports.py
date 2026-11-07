"""Sets the Godot import options of the baked model textures.

The Blender scripts in tools/blender write WebP textures next to each glTF
model. Godot imports them with default options, which keep them lossless and
without mipmaps. This script sets VRAM compression and mipmaps for all of
them, and marks the normal maps as normal maps.

Run it after Godot has created the .import files (one editor or --import
run), then import again:

    python tools/set_texture_imports.py
    godot --headless --path . --import

Use --check to fail (exit code 1) when a texture has the wrong options.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FOLDERS = ["assets/weapons/textures", "assets/attachments/textures", "assets/characters/textures"]

WANT = {
    "compress/mode": "2",
    "compress/high_quality": "false",
    "mipmaps/generate": "true",
    "detect_3d/compress_to": "0",
}


def wanted(path: pathlib.Path) -> dict:
    w = dict(WANT)
    w["compress/normal_map"] = "1" if path.stem.endswith("_normal") else "2"
    return w


def fix(imp: pathlib.Path, check: bool) -> bool:
    text = imp.read_text(encoding="utf-8")
    want = wanted(imp.with_suffix(""))
    changed = False
    for key, val in want.items():
        pat = re.compile(r"^%s=.*$" % re.escape(key), re.M)
        line = "%s=%s" % (key, val)
        if pat.search(text):
            if not re.search(r"^%s$" % re.escape(line), text, re.M):
                text = pat.sub(line, text)
                changed = True
        else:
            text = text.rstrip("\n") + "\n" + line + "\n"
            changed = True
    if changed and not check:
        imp.write_text(text, encoding="utf-8", newline="\n")
    return changed


def main() -> int:
    check = "--check" in sys.argv
    bad = []
    missing = []
    for folder in FOLDERS:
        d = ROOT / folder
        if not d.is_dir():
            continue
        for tex in sorted(d.glob("*.webp")):
            imp = tex.with_name(tex.name + ".import")
            if not imp.exists():
                missing.append(str(tex.relative_to(ROOT)))
                continue
            if fix(imp, check):
                bad.append(str(imp.relative_to(ROOT)))
    for m in missing:
        print("NO IMPORT FILE:", m)
    if check:
        for b in bad:
            print("WRONG OPTIONS:", b)
        return 1 if bad or missing else 0
    print("updated %d import files" % len(bad))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
