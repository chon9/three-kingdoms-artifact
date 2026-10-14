#!/usr/bin/env python3
"""Shrinks generated artwork to the size the game draws and re-encodes it.

Card art (default): the game never shows card art taller than 768 px
(scripts/ui/card_art.gd MAX_ART_HEIGHT), so committing 1024x1536 PNG masters
(about 3 MB each) only bloats the repository. Every oversized image in the
given folders becomes a 768 px tall JPEG (quality 85, about 120 KB) next to
it; images with transparency are kept as PNG (resized only).

Board and UI art (--ui, default folder assets/art/ui):
  opaque backgrounds (boards, river, paper, screens, card back)
      -> JPEG quality 85, at most 1536 px wide
  transparent tall sprites (towers, the capital)
      -> PNG, at most 768 px tall
  transparent icons and emblems (coin, gem, token, faction emblems)
      -> PNG, at most 512 px on the longer side
The transparent PNGs are stored as 256-colour palettes with dithering
(about a quarter of the size, indistinguishable at the sizes the game draws
them); --full-color keeps them RGBA.

Either way the original master is first copied into a folder outside the
repository tree that Godot does not import (default: .tools/art_masters/,
gitignored), unless a master is already there.

    pip install pillow
    python tools/optimize_art.py                      # assets/art/cards
    python tools/optimize_art.py --ui                 # assets/art/ui
    python tools/optimize_art.py assets/art/ui --keep-png

The loaders (card_art.gd, UiKit.tex) look for <name>.png, then .jpg, then
.webp, so the art pipeline can keep writing PNG masters: run this again
before committing, then let Godot import the new files.
"""
import argparse
import os
import shutil
import sys

from PIL import Image

MAX_HEIGHT = 768
QUALITY = 85
UI_MAX_WIDTH = 1536
UI_SPRITE_MAX_HEIGHT = 768
UI_ICON_MAX = 512
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")


def has_transparency(image):
    """True when the image has an alpha channel that is not fully opaque."""
    if image.mode in ("RGBA", "LA"):
        return image.getchannel("A").getextrema()[0] < 255
    return image.mode == "P" and "transparency" in image.info


def relative_path(path):
    """`path` relative to the repository, or its name when it lies elsewhere."""
    try:
        relative = os.path.relpath(path, ROOT)
    except ValueError:
        return os.path.basename(path)
    return os.path.basename(path) if relative.startswith("..") else relative


def keep_master(path, masters):
    master = os.path.join(masters, relative_path(path))
    os.makedirs(os.path.dirname(master), exist_ok=True)
    if not os.path.exists(master):
        shutil.copy2(path, master)


def replace_with(path, output):
    """Removes the original (and its Godot import file) when the output has
    a different name."""
    if output != path:
        os.remove(path)
        stale_import = path + ".import"
        if os.path.exists(stale_import):
            os.remove(stale_import)


def resized(image, width, height):
    if (width, height) == image.size:
        return image
    return image.resize((width, height), Image.LANCZOS)


def optimize(path, masters, keep_png):
    image = Image.open(path)
    image.load()
    width, height = image.size
    has_alpha = has_transparency(image)
    is_jpeg = path.lower().endswith((".jpg", ".jpeg"))
    if height <= MAX_HEIGHT and (is_jpeg or has_alpha or keep_png):
        return None
    if height > MAX_HEIGHT:
        width = round(width * MAX_HEIGHT / height)
        image = image.resize((width, MAX_HEIGHT), Image.LANCZOS)
    stem, extension = os.path.splitext(path)
    keep_master(path, masters)
    if has_alpha or keep_png:
        output = stem + extension
        image.save(output, "PNG", optimize=True)
    else:
        output = stem + ".jpg"
        image.convert("RGB").save(output, "JPEG", quality=QUALITY, optimize=True)
        replace_with(path, output)
    return output


def optimize_ui(path, masters, full_color=False):
    """Board and UI art: see the module docstring for the three classes."""
    image = Image.open(path)
    image.load()
    width, height = image.size
    stem, extension = os.path.splitext(path)
    if not has_transparency(image):
        scale = min(1.0, UI_MAX_WIDTH / width)
        size = (round(width * scale), round(height * scale))
        if extension.lower() in (".jpg", ".jpeg") and size == (width, height):
            return None
        keep_master(path, masters)
        output = stem + ".jpg"
        resized(image, *size).convert("RGB").save(output, "JPEG", quality=QUALITY, optimize=True)
        replace_with(path, output)
        return output
    if height > width * 1.2:
        scale = min(1.0, UI_SPRITE_MAX_HEIGHT / height)
    else:
        scale = min(1.0, UI_ICON_MAX / max(width, height))
    size = (round(width * scale), round(height * scale))
    palette = image.mode == "P"
    if size == (width, height) and extension.lower() == ".png" and (palette or full_color):
        return None
    keep_master(path, masters)
    output = stem + ".png"
    result = resized(image.convert("RGBA"), *size)
    if not full_color:
        result = result.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    result.save(output, "PNG", optimize=True)
    replace_with(path, output)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folders", nargs="*")
    parser.add_argument("--masters", default=os.path.join(ROOT, ".tools", "art_masters"))
    parser.add_argument("--keep-png", action="store_true", help="resize PNGs in place instead of converting to JPEG")
    parser.add_argument("--ui", action="store_true", help="board and UI art rules (backgrounds, sprites, icons)")
    parser.add_argument("--full-color", action="store_true", help="with --ui: keep transparent PNGs RGBA (no palette)")
    args = parser.parse_args()
    folders = args.folders or (["assets/art/ui"] if args.ui else ["assets/art/cards"])
    # Keep Godot from importing the masters (the default folder is inside the project).
    os.makedirs(args.masters, exist_ok=True)
    ignore = os.path.join(args.masters, ".gdignore")
    if not os.path.exists(ignore):
        open(ignore, "w").close()
    before = after = 0
    changed = 0
    for folder in folders:
        folder = folder if os.path.isabs(folder) else os.path.join(ROOT, folder)
        for name in sorted(os.listdir(folder)):
            if not name.lower().endswith(EXTENSIONS):
                continue
            path = os.path.join(folder, name)
            size = os.path.getsize(path)
            output = optimize_ui(path, args.masters, args.full_color) if args.ui else optimize(path, args.masters, args.keep_png)
            if output is None:
                continue
            changed += 1
            before += size
            after += os.path.getsize(output)
            with Image.open(output) as result:
                dimensions = "%dx%d" % result.size
            print("%s -> %s %s (%d KB)" % (relative_path(path), os.path.basename(output), dimensions, os.path.getsize(output) // 1024))
    print("%d images: %.1f MB -> %.1f MB; masters in %s" % (changed, before / 1e6, after / 1e6, args.masters))
    return 0


if __name__ == "__main__":
    sys.exit(main())
