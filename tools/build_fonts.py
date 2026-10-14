#!/usr/bin/env python3
"""Builds the subset UI fonts in assets/fonts/ from the full upstream fonts.

The full fonts (about 70 MB) stay out of the repository; only subsets are
committed. Run this again whenever i18n/ui.csv or data/locale/*.json gain new
characters (tests/i18n_test.gd fails when a used character is missing).

    pip install fonttools
    python tools/build_fonts.py --src <folder with the full fonts> [--download]

Inputs (in --src):
  LXGWWenKai-Medium.ttf   https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Medium.ttf
  NotoSansSC-Regular.otf  https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
  NotoSansSC-Bold.otf     https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Bold.otf

Outputs (in assets/fonts/):
  SanguoKai-Medium.ttf    LXGW WenKai Medium subset, renamed: the OFL Reserved
                          Font Names ("LXGW", "霞鹜", ...) may not be used by a
                          Modified Version embedded in a game.
  NotoSansSC-Regular.otf  Noto Sans SC subsets (OFL, no reserved names).
  NotoSansSC-Bold.otf

Character set: GB2312 level 1 (3,755 common hanzi), every character used in
i18n/ui.csv, data/locale/*.json, docs/art/* (reserve hero names) and non-ASCII
literals in scripts/, plus ASCII, Latin-1, general punctuation, CJK and
full-width punctuation, arrows and a few geometric shapes.
"""
import argparse
import glob
import os
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KAI_FAMILY = "Sanguo Kai"
KAI_POSTSCRIPT = "SanguoKai-Medium"
SOURCES = {
	"LXGWWenKai-Medium.ttf": "https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Medium.ttf",
	"NotoSansSC-Regular.otf": "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf",
	"NotoSansSC-Bold.otf": "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Bold.otf",
}
OUTPUTS = {
	"LXGWWenKai-Medium.ttf": "SanguoKai-Medium.ttf",
	"NotoSansSC-Regular.otf": "NotoSansSC-Regular.otf",
	"NotoSansSC-Bold.otf": "NotoSansSC-Bold.otf",
}
TEXT_GLOBS = ["i18n/*.csv", "data/locale/*.json", "docs/art/*", "scripts/**/*.gd"]
RANGES = [
	(0x0020, 0x007E),  # ASCII
	(0x00A0, 0x00FF),  # Latin-1 (Lü, ×, ·)
	(0x0100, 0x017F),  # Latin Extended-A (romanized names)
	(0x01CD, 0x01DC),  # Pinyin tone letters (ǎ ǐ ǒ ǔ ǖ ǘ ǚ ǜ)
	(0x2010, 0x2027),  # Dashes, quotes, bullet, ellipsis
	(0x2030, 0x203A),
	(0x2190, 0x2199),  # Arrows
	(0x2212, 0x2212),  # Minus sign
	(0x25A0, 0x25A1), (0x25B2, 0x25B3), (0x25B6, 0x25B7), (0x25BC, 0x25BD),
	(0x25C0, 0x25C1), (0x25CB, 0x25CB), (0x25CF, 0x25CF),  # Shapes
	(0x3000, 0x303F),  # CJK punctuation
	(0xFF00, 0xFFEF),  # Full-width forms
]


def gb2312_level1() -> set:
	chars = set()
	for high in range(0xB0, 0xD8):
		for low in range(0xA1, 0xFF):
			try:
				chars.add(bytes([high, low]).decode("gb2312"))
			except UnicodeDecodeError:
				pass
	return chars


def used_characters() -> set:
	chars = set()
	for pattern in TEXT_GLOBS:
		for path in glob.glob(os.path.join(ROOT, pattern), recursive=True):
			if os.path.isfile(path):
				with open(path, encoding="utf-8", errors="ignore") as handle:
					chars.update(ch for ch in handle.read() if ord(ch) > 0x7E)
	return chars


def charset() -> set:
	chars = gb2312_level1() | used_characters()
	for start, end in RANGES:
		chars.update(chr(code) for code in range(start, end + 1))
	return {ch for ch in chars if ch.isprintable() or ch == "　"}


def rename_kai(path: str) -> None:
	font = TTFont(path)
	names = font["name"]
	for record in list(names.names):
		value = None
		if record.nameID in (1, 16):
			value = KAI_FAMILY
		elif record.nameID == 4:
			value = KAI_FAMILY + " Medium"
		elif record.nameID == 3:
			value = KAI_POSTSCRIPT + ";subset"
		elif record.nameID == 6:
			value = KAI_POSTSCRIPT
		elif record.nameID == 17:
			value = "Medium"
		elif record.nameID in (18, 21, 22, 25):
			names.removeNames(nameID=record.nameID)
			continue
		if value is not None:
			record.string = value
	if "CFF " in font:
		font["CFF "].cff.fontNames = [KAI_POSTSCRIPT]
	font.save(path)


def build(source: str, target: str, chars: set) -> None:
	options = subset.Options()
	options.layout_features = ["*"]
	options.name_IDs = ["*"]
	options.name_languages = ["*"]
	options.notdef_outline = True
	options.hinting = False
	options.glyph_names = False
	font = subset.load_font(source, options)
	subsetter = subset.Subsetter(options)
	subsetter.populate(unicodes=[ord(ch) for ch in chars])
	subsetter.subset(font)
	subset.save_font(font, target, options)
	font.close()


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--src", required=True, help="folder holding the full upstream fonts")
	parser.add_argument("--out", default=os.path.join(ROOT, "assets", "fonts"))
	parser.add_argument("--download", action="store_true", help="fetch missing upstream fonts into --src")
	args = parser.parse_args()
	os.makedirs(args.out, exist_ok=True)
	chars = charset()
	for name, url in SOURCES.items():
		source = os.path.join(args.src, name)
		if not os.path.exists(source):
			if not args.download:
				print("Missing %s (use --download or fetch %s)" % (source, url), file=sys.stderr)
				return 1
			os.makedirs(args.src, exist_ok=True)
			urllib.request.urlretrieve(url, source)
		target = os.path.join(args.out, OUTPUTS[name])
		build(source, target, chars)
		if name.startswith("LXGW"):
			rename_kai(target)
		print("%s: %d KB" % (os.path.relpath(target, ROOT), os.path.getsize(target) // 1024))
	print("%d characters" % len(chars))
	return 0


if __name__ == "__main__":
	sys.exit(main())
