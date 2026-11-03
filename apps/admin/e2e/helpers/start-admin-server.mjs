// E2E harness only; this never changes the application's font setup.
// The fixture isolates a legacy Google loader if present. Pinned local font
// stylesheets do not use this hook. Neither path is a visual typography test.
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const port = Number(process.argv[2]);
if (!Number.isInteger(port) || port < 1 || port > 65534) {
  throw new Error('Pass a valid admin E2E port to the isolated launcher.');
}

const font = readFileSync(
  new URL('../fixtures/fonts/noto-sans-jp-latin.woff2', import.meta.url)
);
const fontServer = createServer((request, response) => {
  if (
    request.url !== '/noto-sans-jp-latin.woff2' ||
    !['GET', 'HEAD'].includes(request.method ?? '')
  ) {
    response.writeHead(404).end();
    return;
  }
  response.writeHead(200, {
    'Content-Type': 'font/woff2',
    'Content-Length': font.length,
    'Cache-Control': 'no-store',
  });
  response.end(request.method === 'HEAD' ? undefined : font);
});
await new Promise((resolve, reject) => {
  fontServer.once('error', reject);
  fontServer.listen(port + 1, '127.0.0.1', resolve);
});
const mockFile = fileURLToPath(
  new URL('../fixtures/fonts/google-responses.cjs', import.meta.url)
);

const require = createRequire(import.meta.url);
const nextServer = spawn(
  process.execPath,
  [
    require.resolve('next/dist/bin/next'),
    'dev',
    '--hostname',
    '127.0.0.1',
    '--port',
    String(port),
  ],
  {
    stdio: 'inherit',
    env: {
      ...process.env,
      // Next's existing test hook is scoped to this E2E child, never production.
      NEXT_FONT_GOOGLE_MOCKED_RESPONSES: mockFile,
    },
  }
);
const cleanUp = () => {
  fontServer.close();
};
nextServer.once('error', (error) => {
  console.error(error);
  cleanUp();
  process.exitCode = 1;
});
nextServer.once('exit', (code) => {
  cleanUp();
  process.exitCode = code ?? 1;
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => nextServer.kill(signal));
}
