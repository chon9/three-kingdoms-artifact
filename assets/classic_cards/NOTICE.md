# Artifact Classic card images

The image manifest points to original Artifact card images on Valve's public Steam CDN, referenced by preserved Valve CardSet API responses. The local PNGs are downloaded for this user's playable prototype and are excluded from Git.

These images and card identities are Valve/artist content. They are **not covered by this repository's MIT source-code license**. Artist names and source URLs are recorded in `manifest.json`. The source repository provides the manifest and a downloader rather than claiming to relicense the artwork.

No modified PNGs are generated. With the Classic card theme the game crops the art window of each original render and draws the card frame, name, rules text and stats itself, so text and stats printed on older archived fronts (for example pre-patch Axe stats, Gust text and equipment prices) are not shown. The underlying files remain unchanged.
