import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';

// Files that legitimately contain CJK characters (display locale names, etc.)
const ALLOWLIST = ['locale-switcher.tsx'];

// CJK Unicode ranges: Hiragana, Katakana, CJK Unified Ideographs, Hangul Syllables, Fullwidth Forms
const CJK_PATTERN = /[\u3000-\u9FFF\uAC00-\uD7AF\uFF00-\uFFEF]/;

function findTsxFiles(dir: string): string[] {
  const results: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (
      entry.isDirectory() &&
      entry.name !== 'node_modules' &&
      entry.name !== '__tests__'
    ) {
      results.push(...findTsxFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.tsx')) {
      results.push(fullPath);
    }
  }
  return results;
}

describe('hardcoded CJK strings', () => {
  it('no .tsx source files contain CJK characters outside allowlist', () => {
    const srcDir = path.resolve(__dirname, '..');
    const files = findTsxFiles(srcDir);
    const violations: string[] = [];

    for (const filePath of files) {
      const fileName = path.basename(filePath);
      if (ALLOWLIST.includes(fileName)) continue;

      const content = fs.readFileSync(filePath, 'utf-8');
      const lines = content.split('\n');

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]!;
        // Skip import lines and comments
        if (
          line.trimStart().startsWith('import ') ||
          line.trimStart().startsWith('//')
        )
          continue;
        if (CJK_PATTERN.test(line)) {
          const relativePath = path.relative(srcDir, filePath);
          violations.push(`${relativePath}:${i + 1}: ${line.trim()}`);
        }
      }
    }

    expect(
      violations,
      `Found ${violations.length} hardcoded CJK string(s):\n${violations.join('\n')}`
    ).toEqual([]);
  });
});
