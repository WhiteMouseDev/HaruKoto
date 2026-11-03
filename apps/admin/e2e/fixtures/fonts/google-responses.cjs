// Next.js test hook, loaded only by the E2E child server. Keep its URL stable
// across dev restarts so Turbopack never caches an expired fixture endpoint.
const fontPort = Number(process.env.ADMIN_E2E_PORT ?? 3101) + 1;

module.exports = {
  'https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;600&display=swap': `/* latin */
@font-face {
  font-family: 'Noto Sans JP';
  font-style: normal;
  font-weight: 400 600;
  font-display: swap;
  src: url(http://127.0.0.1:${fontPort}/noto-sans-jp-latin.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}`,
};
