# Pinned Noto Sans web fonts

These are unmodified variable WOFF2 subsets downloaded from the official Google
Fonts CSS API. Their original licenses are included. `manifest.json` records the
source URLs, download time, user agent, byte counts, and SHA-256 of every asset,
original stylesheet, generated stylesheet, and license. The license URLs are
pinned to commits in the official google/fonts repository.

The generated CSS uses the existing application weight range 400–700,
`font-display: swap`, original Unicode ranges, and existing Arial fallback
metrics. Fonts are named `HaruKoto Noto Sans KR` and `HaruKoto Noto Sans JP` to
avoid collisions with installed fonts. Their existing application CSS variables
remain `--font-noto-sans-kr` and `--font-noto-sans-jp`.

All three Next.js apps import these stylesheets directly. Relative CSS URLs let
the bundler emit content-hashed font assets with Next.js static caching. No
Google request is necessary during builds or at runtime. Do not turn the subsets
into interchangeable sources or remove their Unicode ranges: that would change
glyph coverage or force multi-megabyte font downloads for short text.

No font preload is added: glyph-specific CSS loading avoids preloading every
subset and avoids pinning implementation-specific hashed output URLs. The old
Google loader preloaded Latin only. CJK remains glyph-driven as before; validate
font rendering and transfer size in browser checks before release.
