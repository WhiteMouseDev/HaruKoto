import assert from 'node:assert/strict';
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkFontAssets } from '../scripts/check-font-assets.mjs';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'harukoto-font-check-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  cpSync(
    path.join(repositoryRoot, 'assets/fonts'),
    path.join(root, 'assets/fonts'),
    { recursive: true }
  );
  for (const app of ['web', 'admin', 'landing']) {
    cpSync(
      path.join(repositoryRoot, `apps/${app}/src/app`),
      path.join(root, `apps/${app}/src/app`),
      {
        recursive: true,
        filter: (source) =>
          !path.extname(source) || path.basename(source) === 'layout.tsx',
      }
    );
  }
  return root;
}

test('the checked-in original font shards and consumers are complete', () => {
  assert.deepEqual(checkFontAssets(), { assets: 248, totalBytes: 8976828 });
});

test('a missing rarely used font shard fails even when application builds could succeed', (t) => {
  const root = fixture(t);
  const manifest = JSON.parse(
    readFileSync(path.join(root, 'assets/fonts/manifest.json'), 'utf8')
  );
  rmSync(path.join(root, 'assets/fonts', manifest.families[1].assets[0].file));
  assert.throws(() => checkFontAssets(root), /ENOENT/);
});

test('altered font bytes fail against their pinned source digest', (t) => {
  const root = fixture(t);
  const manifest = JSON.parse(
    readFileSync(path.join(root, 'assets/fonts/manifest.json'), 'utf8')
  );
  const target = path.join(
    root,
    'assets/fonts',
    manifest.families[0].assets[0].file
  );
  const bytes = readFileSync(target);
  bytes[bytes.length - 1] ^= 1;
  writeFileSync(target, bytes);
  assert.throws(() => checkFontAssets(root), /checksum/);
});

test('reintroducing Google font loading in any surface is rejected', (t) => {
  const root = fixture(t);
  const target = path.join(root, 'apps/landing/src/app/layout.tsx');
  writeFileSync(
    target,
    `${readFileSync(target, 'utf8')}\nimport { Noto_Sans_JP } from 'next/font/google';\n`
  );
  assert.throws(() => checkFontAssets(root), /build-time font download/);
});
