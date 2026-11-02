import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = fileURLToPath(new URL('../../', import.meta.url));
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const faces = (css) =>
  [...css.matchAll(/@font-face\s*\{([^}]+)\}/g)].map((match) => match[1]);
const property = (face, name) =>
  face.match(new RegExp(`(?:^|[;\\n])\\s*${name}:\\s*([^;]+)`))?.[1].trim();
const normalized = (value) => value.replace(/\s+/g, '').toLowerCase();

export function checkFontAssets(root = repositoryRoot) {
  const turbo = JSON.parse(readFileSync(path.join(root, 'turbo.json'), 'utf8'));
  assert(
    turbo.globalDependencies?.includes('assets/fonts/**'),
    'Shared font changes must invalidate the build cache'
  );
  const directory = path.join(root, 'assets/fonts');
  const manifest = JSON.parse(
    readFileSync(path.join(directory, 'manifest.json'), 'utf8')
  );
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.declaredWeightRange, '400 700');
  assert.equal(manifest.display, 'swap');
  assert.deepEqual(
    manifest.families.map((family) => family.upstreamFamily).sort(),
    ['Noto Sans JP', 'Noto Sans KR']
  );
  const expectedFiles = new Set();
  let totalBytes = 0;

  for (const family of manifest.families) {
    assert.equal(
      family.assets.length,
      124,
      `${family.upstreamFamily}: missing subsets`
    );
    for (const record of [
      family.sourceCss,
      family.license,
      family.generatedCss,
    ]) {
      assert(
        !path.isAbsolute(record.file) && !record.file.split('/').includes('..')
      );
      assert.equal(
        sha256(readFileSync(path.join(directory, record.file))),
        record.sha256,
        `${record.file}: checksum`
      );
    }
    assert.equal(family.license.spdx, 'OFL-1.1');
    assert.match(
      family.license.sourceUrl,
      /^https:\/\/raw\.githubusercontent\.com\/google\/fonts\/[0-9a-f]{40}\/ofl\/notosans(?:kr|jp)\/OFL\.txt$/
    );
    assert.match(
      readFileSync(path.join(directory, family.license.file), 'utf8'),
      /SIL OPEN FONT LICENSE Version 1\.1/
    );

    const source = faces(
      readFileSync(path.join(directory, family.sourceCss.file), 'utf8')
    );
    const css = readFileSync(
      path.join(directory, family.generatedCss.file),
      'utf8'
    );
    const local = faces(css).filter((face) => property(face, 'unicode-range'));
    assert.equal(
      local.length,
      family.assets.length,
      `${family.cssFamily}: Unicode faces`
    );
    assert(
      !/https?:\/\//.test(css),
      `${family.generatedCss.file}: external font request`
    );
    assert(
      css.includes(family.cssVariable),
      `${family.generatedCss.file}: CSS variable`
    );

    for (const asset of family.assets) {
      assert.match(
        asset.file,
        /^noto-sans-(?:kr|jp)-\d{3}-[0-9a-f]{12}\.woff2$/
      );
      assert(!expectedFiles.has(asset.file), `Duplicate asset ${asset.file}`);
      expectedFiles.add(asset.file);
      const upstream = new URL(asset.sourceUrl);
      assert.equal(upstream.origin, 'https://fonts.gstatic.com');
      const bytes = readFileSync(path.join(directory, asset.file));
      assert.equal(
        bytes.subarray(0, 4).toString(),
        'wOF2',
        `${asset.file}: invalid WOFF2`
      );
      assert.equal(
        bytes.readUInt32BE(8),
        bytes.length,
        `${asset.file}: truncated WOFF2`
      );
      assert.equal(bytes.length, asset.bytes);
      assert.equal(sha256(bytes), asset.sha256, `${asset.file}: checksum`);
      totalBytes += bytes.length;

      const face = local.find((item) =>
        property(item, 'src')?.includes(`'./${asset.file}'`)
      );
      assert(face, `${asset.file}: not referenced locally`);
      assert.equal(property(face, 'font-family'), `'${family.cssFamily}'`);
      assert.equal(property(face, 'font-weight'), '400 700');
      assert.equal(property(face, 'font-display'), 'swap');
      assert.equal(
        normalized(property(face, 'unicode-range')),
        normalized(asset.unicodeRange)
      );
      const originals = source.filter((item) =>
        property(item, 'src')?.includes(asset.sourceUrl)
      );
      assert.equal(
        originals.length,
        4,
        `${asset.file}: original weight coverage`
      );
      assert.deepEqual(
        originals.map((item) => property(item, 'font-weight')).sort(),
        ['400', '500', '600', '700']
      );
      assert(
        originals.every(
          (item) =>
            normalized(property(item, 'unicode-range')) ===
            normalized(asset.unicodeRange)
        ),
        `${asset.file}: changed glyph coverage`
      );
    }
  }
  assert.deepEqual(
    readdirSync(directory)
      .filter((file) => file.endsWith('.woff2'))
      .sort(),
    [...expectedFiles].sort()
  );

  for (const app of ['web', 'admin', 'landing']) {
    const layout = readFileSync(
      path.join(root, `apps/${app}/src/app/layout.tsx`),
      'utf8'
    );
    assert(
      !layout.includes('next/font/google'),
      `${app}: build-time font download restored`
    );
    const families = app === 'admin' ? ['jp'] : ['kr', 'jp'];
    for (const family of families) {
      assert(
        layout.includes(`../../../../assets/fonts/noto-sans-${family}.css`),
        `${app}: missing local ${family} font`
      );
    }
  }
  return { assets: expectedFiles.size, totalBytes };
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const result = checkFontAssets();
  console.log(
    `Verified ${result.assets} pinned WOFF2 subsets (${result.totalBytes} bytes), licenses, original Unicode ranges, and local app imports.`
  );
}
