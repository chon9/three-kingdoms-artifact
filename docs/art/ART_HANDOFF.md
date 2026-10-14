# Generated artwork handoff

All 111 entries in `ART_PROMPTS.md` have a final generated image in the workspace: 49 current card illustrations, 38 reserve hero portraits, and 24 board/UI assets. These were created with the OpenAI built-in image generation tool using the project prompts and our generated Guan Yu as the style anchor. No downloaded game artwork was used.

Liu Bei's final `assets/art/heroes_reserve/liubei.png` replaces the faulty crossed-sword pose with one complete, separately gripped sword in each hand. His face, costume and background were preserved.

## Files and provenance

| Deliverable | Location |
|---|---|
| Current game card art | `assets/art/cards/` — 49 optimized JPEGs |
| Reserve heroes | `assets/art/heroes_reserve/` — 38 full-resolution PNGs |
| Board and UI assets | `assets/art/ui/` — 24 PNGs |
| All 111 final PNG masters | `.tools/art_masters/assets/art/` — mirrored original requested paths |
| Final prompts, references and revision prompts | [generated_art_manifest.json](generated_art_manifest.json) |
| File dimensions, alpha checks and master SHA-256 hashes | [art_asset_validation.json](art_asset_validation.json) |
| Entry-by-entry review status | [GENERATION_STATUS.md](GENERATION_STATUS.md) |

The existing optimizer converted the 49 current card PNGs to 512×768 JPEGs for runtime use. Every final full-resolution PNG is preserved in the master mirror. The manifest distinguishes requested paths, actual runtime paths, native dimensions and master paths. Reserve portraits and `.tools/` are currently gitignored by the project; the images exist locally even though ordinary `git status` does not list them.

## Validation and integration notes

All 111 runtime images were decoded successfully. All 111 master copies match the final generated source by SHA-256. Each of the 12 requested transparent sprites contains real transparent pixels. Godot 4.5.2 completed `--headless --editor --import --quit` successfully, and runtime image import sidecars were checked.

Native output dimensions are 1024×1536 for 93 portrait assets, 1536×1024 for 10 landscapes, and 1254×1254 for eight square assets. The tool returned larger square PNGs than the requested 1024×1024; their original pixels and alpha were preserved. Size their UI controls by the desired display dimensions rather than native texture dimensions.

Tower and capital sprites retain soft translucent warm halos despite background-removal edits. They have alpha, but they are not tight hard-edged cutouts. Check them over the final board colours. Their visible building bounds and baselines also vary slightly between states; normalize the visible structure scale and align the stone base when displaying transitions.

The paper and river backgrounds are quiet textures, but are not mathematically exact seamless tiles. Mean opposite-edge RGB differences on the 0–255 scale were 8.55 horizontally / 8.08 vertically for paper, and 15.21 horizontally for the river. Use the river as a single stretched divider or review its horizontal repeat boundary before enabling repeat. Review a 2×2 paper repeat in the actual menu. These edge checks do not substitute for a visual in-game tile check.

The generation work changed artwork and its documentation. Game logic and UI implementation remain with Claude Code.
