import { describe, it, expect } from 'vitest';
import ko from '../../messages/ko.json';
import ja from '../../messages/ja.json';
import en from '../../messages/en.json';

function flatKeys(obj: Record<string, unknown>, prefix = ''): string[] {
  return Object.entries(obj).flatMap(([k, v]) =>
    typeof v === 'object' && v !== null
      ? flatKeys(v as Record<string, unknown>, prefix ? `${prefix}.${k}` : k)
      : [prefix ? `${prefix}.${k}` : k]
  );
}

describe('locale key parity', () => {
  it('ko, ja, en have identical key sets', () => {
    const koKeys = flatKeys(ko).sort();
    const jaKeys = flatKeys(ja).sort();
    const enKeys = flatKeys(en).sort();

    // Find missing keys for better error messages
    const koSet = new Set(koKeys);
    const jaSet = new Set(jaKeys);
    const enSet = new Set(enKeys);

    const missingInJa = koKeys.filter((k) => !jaSet.has(k));
    const missingInEn = koKeys.filter((k) => !enSet.has(k));
    const missingInKo = jaKeys.filter((k) => !koSet.has(k));

    expect(missingInJa, 'Keys in ko.json missing from ja.json').toEqual([]);
    expect(missingInEn, 'Keys in ko.json missing from en.json').toEqual([]);
    expect(missingInKo, 'Keys in ja.json missing from ko.json').toEqual([]);
    expect(jaKeys).toEqual(koKeys);
    expect(enKeys).toEqual(koKeys);
  });
});
