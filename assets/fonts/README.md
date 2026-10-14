# Fonts

Subsets built by `tools/build_fonts.py` (GB2312 level 1 plus every character
used by the game text). Rebuild after adding text with new characters;
`tests/i18n_test.gd` fails when a used character is missing.

| File | Source | License |
|---|---|---|
| `SanguoKai-Medium.ttf` | LXGW WenKai Medium v1.522, https://github.com/lxgw/LxgwWenKai | SIL OFL 1.1, `OFL-SanguoKai.txt` |
| `NotoSansSC-Regular.otf`, `NotoSansSC-Bold.otf` | Noto Sans SC 2.004, https://github.com/notofonts/noto-cjk | SIL OFL 1.1, `OFL-NotoSansSC.txt` |

`SanguoKai-Medium.ttf` is a Modified Version of LXGW WenKai under the OFL. Its
family is renamed to "Sanguo Kai" because the Reserved Font Names ("LXGW",
"霞鹜", "霞鶩", "落霞孤鹜", "落霞孤鶩") may not be used by a subset embedded in
a game. The original copyright notice is kept in the font's name table.

Godot resources: `body.tres` (Noto Sans SC Regular, Kai fallback),
`body_bold.tres` (Noto Sans SC Bold, Kai fallback) and `title.tres` (Sanguo
Kai, Noto fallback). `assets/theme/default_theme.tres` uses `body.tres` as the
project-wide default font.
