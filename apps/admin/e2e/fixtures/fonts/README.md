# E2E-only font fixture

`noto-sans-jp-latin.woff2` is an unmodified Latin subset of the official Google
Fonts Noto Sans JP variable web font, distributed under the included SIL Open
Font License. Its SHA-256 is
`f349e5c5f705a845a4f93d70b63f6e5a4bd139dc3bb5c75e6cf74da6d84940dc`.

Upstream asset: <https://fonts.gstatic.com/s/notosansjp/v57/-F62fjtqLzI2JPCgQBnw7HFYwQgP-FVthw.woff2>.
License source: <https://raw.githubusercontent.com/google/fonts/295d98a7a0c17c68f1341eaeea354e7960ea70d3/ofl/notosansjp/OFL.txt>.

The Playwright launcher serves this single fixture on loopback at the admin
E2E port plus one (3102 by default)
and supplies Next.js's existing `NEXT_FONT_GOOGLE_MOCKED_RESPONSES` test hook to
its child development server. No external Google font request is needed for
admin functional smoke tests. The source layout, production font loader,
Next.js version, and production environment are unchanged.

This is **not a production font asset or a Japanese typography test**. Japanese
text uses browser/system fallback during this suite. Review glyph coverage,
line wrapping, font downloads, and the actual production font separately.

Run the suite with `pnpm --filter @harukoto/admin e2e`. The fixture server is
disposed when the test server exits. Its stable URL and source-controlled CSS
response module also support repeated dev-server runs without stale temporary
font endpoints in the Turbopack cache.
