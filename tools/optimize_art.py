#!/usr/bin/env python3
"""Shrinks generated artwork to the size the game draws and re-encodes it.

The game never shows card art taller than 768 px (scripts/ui/card_art.gd
MAX_ART_HEIGHT), so committing 1024x1536 PNG masters (about 3 MB each) only
bloats the repository. This script turns every oversized image in the given
folders into a 768 px tall JPEG (quality 85, about 120 KB) next to it and
moves the original master into a folder outside the repository tree that
Godot does not import (default: .tools/art_masters/, gitignored).

    pip install pillow
    python tools/optimize_art.py                      # assets/art/cards
    python tools/optimize_art.py assets/art/ui --keep-png

card_art.gd looks for <id>.png, then <id>.jpg, then <id>.webp, so the art
pipeline can keep writing PNG masters: run this again before committing.
Images with transparency are kept as PNG (resized only).
"""
import argparse
import os
import shutil
import sys

from PIL import Image

MAX_HEIGHT = 768
QUALITY = 85
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def optimize(path, masters, keep_png):
    image = Image.open(path)
    image.load()
    width, height = image.size
    has_alpha = image.mode in ("RGBA", "LA") or (image.mode == "P" and "transparency" in image.info)
    is_jpeg = path.lower().endswith((".jpg", ".jpeg"))
    if height <= MAX_HEIGHT and (is_jpeg or has_alpha or keep_png):
        return None
    if height > MAX_HEIGHT:
        width = round(width * MAX_HEIGHT / height)
        image = image.resize((width, MAX_HEIGHT), Image.LANCZOS)
    stem, extension = os.path.splitext(path)
    relative = os.path.relpath(path, ROOT)
    master = os.path.join(masters, relative)
    os.makedirs(os.path.dirname(master), exist_ok=True)
    if not os.path.exists(master):
        shutil.copy2(path, master)
    if has_alpha or keep_png:
        output = stem + extension
        image.save(output, "PNG", optimize=True)
    else:
        output = stem + ".jpg"
        image.convert("RGB").save(output, "JPEG", quality=QUALITY, optimize=True)
        if output != path:
            os.remove(path)
            stale_import = path + ".import"
            if os.path.exists(stale_import):
                os.remove(stale_import)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folders", nargs="*", default=["assets/art/cards"])
    parser.add_argument("--masters", default=os.path.join(ROOT, ".tools", "art_masters"))
    parser.add_argument("--keep-png", action="store_true", help="resize PNGs in place instead of converting to JPEG")
    args = parser.parse_args()
    # Keep Godot from importing the masters (the default folder is inside the project).
    os.makedirs(args.masters, exist_ok=True)
    ignore = os.path.join(args.masters, ".gdignore")
    if not os.path.exists(ignore):
        open(ignore, "w").close()
    before = after = 0
    changed = 0
    for folder in args.folders:
        folder = folder if os.path.isabs(folder) else os.path.join(ROOT, folder)
        for name in sorted(os.listdir(folder)):
            if not name.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                continue
            path = os.path.join(folder, name)
            size = os.path.getsize(path)
            output = optimize(path, args.masters, args.keep_png)
            if output is None:
                continue
            changed += 1
            before += size
            after += os.path.getsize(output)
            print("%s -> %s (%d KB)" % (os.path.relpath(path, ROOT), os.path.basename(output), os.path.getsize(output) // 1024))
    print("%d images: %.1f MB -> %.1f MB; masters in %s" % (changed, before / 1e6, after / 1e6, args.masters))
    return 0


if __name__ == "__main__":
    sys.exit(main())
