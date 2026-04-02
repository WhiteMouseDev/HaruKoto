# Phase 8: i18n Gap Closure — TTS Hook Toast - Research

**Researched:** 2026-04-02
**Domain:** next-intl hook usage in non-component files (.ts hooks), Vitest file-scan pattern extension
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** useTtsPlayer 훅 내부에서 `useTranslations('tts')`를 직접 호출하여 toast 메시지를 번역한다
- **D-02:** `toast.success(t('regenerate.success'))` / `toast.error(t('regenerate.error'))` 패턴 사용
- **D-03:** 기존 `tts` 네임스페이스에 `regenerate.success`, `regenerate.error` 키를 추가한다
- **D-04:** 항상 i18n 메시지 우선 사용 — `toast.error(t('regenerate.error'))`. 서버 에러 메시지(err.message)는 무시하고 일관된 로케일 경험 제공
- **D-05:** `hardcoded-strings.test.ts`의 `findTsxFiles` 함수를 `.ts` + `.tsx` 모두 스캔하도록 확장
- **D-06:** allowlist는 최소 유지 — 현재 `locale-switcher.tsx`만. .ts 확장 후 실패하는 파일이 있으면 정당한 이유 확인 후에만 allowlist 추가
- **D-07:** `__tests__/`, `node_modules/` 디렉토리는 기존대로 제외

### Claude's Discretion
- i18n 키 네이밍 세부 구조 (regenerate.success vs tts.regenerateSuccess 등)
- 테스트 함수명 리팩토링 (findTsxFiles → findSourceFiles 등)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| I18N-04 | 모든 UI 문자열이 i18n 키를 통해 번역된다 (하드코딩 일본어 없음) | use-tts-player.ts line 78/81 contain hardcoded Japanese; replace with t('regenerate.success') / t('regenerate.error') from tts namespace |
| I18N-05 | locale 전환 시 모든 텍스트가 선택된 언어로 표시된다 | Adding regenerate.success and regenerate.error to all 3 locale files (ko/ja/en) ensures toast reflects active locale |
</phase_requirements>

## Summary

Phase 8 is a surgical two-task gap closure. It fixes two hardcoded Japanese strings in `apps/admin/src/hooks/use-tts-player.ts` (lines 78 and 81) and extends the hardcoded-strings test to also scan `.ts` files alongside `.tsx`. Both tasks are independent and can be executed in parallel.

The `tts` namespace already exists in all three locale files with matching keys `regenerateSuccess` and `regenerateError`. However, the decided key path uses dot-notation `regenerate.success` / `regenerate.error` — research confirms the locale files currently use flat keys (`regenerateSuccess`, `regenerateError`). The planner must choose: use the existing flat keys (no locale file change needed) or add new nested keys. This is a Claude's Discretion area — recommendation is to reuse the existing flat keys `tts.regenerateSuccess` and `tts.regenerateError` to avoid adding redundant keys.

The test extension (D-05) requires only changing the `.endsWith('.tsx')` filter in `findTsxFiles` to also match `.ts` and renaming the function to `findSourceFiles` for clarity. After the extension, the now-corrected use-tts-player.ts (no more CJK) will pass the test.

**Primary recommendation:** Reuse existing `tts.regenerateSuccess` / `tts.regenerateError` keys in the hook rather than adding duplicate keys. Rename `findTsxFiles` to `findSourceFiles` and extend the scan to `.ts` files.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| next-intl | (project-installed) | useTranslations hook for i18n | Already used in TtsPlayer component and all page components |
| sonner | ^2.0.7 | toast notifications | Project standard, already imported in use-tts-player.ts |
| vitest | ^4.0.18 | test runner for .test.ts files | Project standard, covers `src/**/*.test.{ts,tsx}` per vitest.config.ts |

No new installations required. All libraries are already installed and configured.

**Installation:** None needed.

## Architecture Patterns

### File Locations
```
apps/admin/
├── src/
│   ├── hooks/
│   │   └── use-tts-player.ts          # MODIFY: lines 78, 81 — replace hardcoded strings
│   └── __tests__/
│       └── hardcoded-strings.test.ts  # MODIFY: extend findTsxFiles to include .ts
├── messages/
│   ├── ko.json                        # READ-ONLY: tts.regenerateSuccess + tts.regenerateError already exist
│   ├── ja.json                        # READ-ONLY: same
│   └── en.json                        # READ-ONLY: same
```

### Pattern 1: useTranslations in a 'use client' hook

`use-tts-player.ts` already has `'use client'` at line 1. React hooks (including `useTranslations`) are valid inside custom hooks that are themselves React hooks. The pattern used in Phase 7 pages applies here:

```typescript
// apps/admin/src/hooks/use-tts-player.ts
'use client';

import { useTranslations } from 'next-intl';
// ...

export function useTtsPlayer(contentType: ContentType, itemId: string) {
  const t = useTranslations('tts');
  // ...
  onSuccess: () => {
    toast.success(t('regenerateSuccess'));
  },
  onError: () => {
    toast.error(t('regenerateError'));
    setConfirmField(null);
  },
```

Source: existing pattern in `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` — `useTranslations` called at hook/component top level, result used in callbacks.

### Pattern 2: Key naming — reuse vs. new keys

Existing keys in all three locale files under `tts` namespace:
- `regenerateSuccess` — ko: "TTS를 재생성했습니다" / ja: "TTSを再生成しました" / en: "TTS regenerated"
- `regenerateError` — ko: "재생성에 실패했습니다. 다시 시도해 주세요." / ja: "再生成に失敗しました。もう一度お試しください。" / en: "Regeneration failed. Please try again."

These keys precisely match the hardcoded strings in the hook. **No locale file changes are needed** if `t('regenerateSuccess')` and `t('regenerateError')` are used.

D-02/D-03 in CONTEXT.md specify `regenerate.success` / `regenerate.error` key paths (nested), but the flat equivalents already exist. This is a Claude's Discretion area — using existing flat keys avoids duplication and is the recommended approach.

### Pattern 3: Extending findTsxFiles to include .ts

Current filter at line 21 of hardcoded-strings.test.ts:
```typescript
} else if (entry.isFile() && entry.name.endsWith('.tsx')) {
```

Extended version:
```typescript
} else if (entry.isFile() && (entry.name.endsWith('.tsx') || entry.name.endsWith('.ts'))) {
```

The function rename from `findTsxFiles` to `findSourceFiles` is optional (Claude's Discretion) but recommended for accuracy. The test description string at line 29 should also be updated from `'no .tsx source files'` to `'no .ts/.tsx source files'`.

### Anti-Patterns to Avoid
- **Adding duplicate i18n keys:** If flat keys `regenerateSuccess`/`regenerateError` already exist, do NOT add `regenerate.success`/`regenerate.error` alongside them. This creates key sprawl and maintenance burden.
- **Passing err.message to toast:** D-04 explicitly requires ignoring `err.message`. Current line 81 is `toast.error(err.message || '...')` — the replacement must be `toast.error(t('regenerateError'))` with no fallback to err.message.
- **Partially extending the test:** The test function name change and the description string must both be updated together to avoid misleading test output.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Locale-aware toast messages | Custom locale detection + string selection | `useTranslations('tts')` from next-intl | next-intl already integrated with Next.js locale routing; useTranslations returns the correct locale automatically |
| File scanning in tests | Custom glob or shell command | Node.js fs.readdirSync (already used) | Pattern is already established in the test; minimal change needed |

## Common Pitfalls

### Pitfall 1: Key path mismatch (nested vs flat)
**What goes wrong:** CONTEXT.md D-02 specifies `t('regenerate.success')` but the locale files have `regenerateSuccess` (flat). Using `t('regenerate.success')` would return undefined (next-intl returns the key string on miss, not an error).
**Why it happens:** CONTEXT.md describes the intent but the actual key structure in locale files uses camelCase flat keys.
**How to avoid:** Read the locale files before writing the hook. Confirm exact key names before implementing.
**Warning signs:** Toast shows the raw key string (e.g., "regenerate.success") instead of translated text.

### Pitfall 2: onError callback still references err.message
**What goes wrong:** Current code is `toast.error(err.message || '...')`. If the developer keeps `err.message` as a fallback, server-side Japanese error messages can still leak through.
**Why it happens:** Refactoring instinct is to keep the fallback.
**How to avoid:** Replace the entire expression with `toast.error(t('regenerateError'))` — no fallback, per D-04.

### Pitfall 3: .ts extension scan picks up test files or type-only files
**What goes wrong:** `.ts` extension includes files in `__tests__/` (already excluded by D-07), but also includes utility files in `lib/`, `hooks/`, and `types/` that might contain CJK in legitimate contexts (e.g., comments).
**Why it happens:** Broader scan catches more files.
**How to avoid:** The current exclusion of `__tests__/` directory (D-07) is already in the findTsxFiles logic. The comment-line skip (`line.trimStart().startsWith('//')`) is also already there. No additional changes needed — the existing guards are sufficient.

### Pitfall 4: Forgetting to update the test description string
**What goes wrong:** Function is renamed to `findSourceFiles` but the `it()` description still says `'no .tsx source files...'`. The test passes but the description is misleading.
**How to avoid:** Update both the function call and the description string atomically.

## Code Examples

### Final use-tts-player.ts mutation callbacks
```typescript
// Source: apps/admin/src/hooks/use-tts-player.ts (modified)
const t = useTranslations('tts');  // add at top of useTtsPlayer function

const regenerateMutation = useMutation({
  mutationFn: (field: string) => regenerateTts(contentType, itemId, field),
  onSuccess: (newData, field) => {
    void queryClient.invalidateQueries({
      queryKey: ['admin-tts', contentType, itemId],
    });
    if (newData.audioUrl) {
      audioRef.current?.pause();
      audioRef.current = new Audio(newData.audioUrl);
      audioRef.current.addEventListener('ended', () => setPlayingField(null));
      void audioRef.current.play();
      setPlayingField(field);
    }
    setConfirmField(null);
    toast.success(t('regenerateSuccess'));  // was: toast.success('TTSを再生成しました')
  },
  onError: () => {
    toast.error(t('regenerateError'));  // was: toast.error(err.message || '再生成に失敗しました。もう一度お試しください。')
    setConfirmField(null);
  },
});
```

Note: `onError` signature can drop the `err: Error` parameter entirely since it is no longer used (per D-04).

### Extended findSourceFiles in hardcoded-strings.test.ts
```typescript
// Source: apps/admin/src/__tests__/hardcoded-strings.test.ts (modified)
function findSourceFiles(dir: string): string[] {
  const results: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (
      entry.isDirectory() &&
      entry.name !== 'node_modules' &&
      entry.name !== '__tests__'
    ) {
      results.push(...findSourceFiles(fullPath));
    } else if (
      entry.isFile() &&
      (entry.name.endsWith('.tsx') || entry.name.endsWith('.ts'))
    ) {
      results.push(fullPath);
    }
  }
  return results;
}

describe('hardcoded CJK strings', () => {
  it('no .ts/.tsx source files contain CJK characters outside allowlist', () => {
    const srcDir = path.resolve(__dirname, '..');
    const files = findSourceFiles(srcDir);  // renamed from findTsxFiles
    // ... rest unchanged
  });
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded Japanese toast in hook | useTranslations('tts') | Phase 8 | Toasts now respect active locale |
| .tsx-only CJK scan | .ts + .tsx CJK scan | Phase 8 | Prevents future .ts file regressions |

## Existing Key Inventory (confirmed by reading locale files)

All three locale files already contain exactly the right translations:

| Key | ko.json | ja.json | en.json |
|-----|---------|---------|---------|
| `tts.regenerateSuccess` | "TTS를 재생성했습니다" | "TTSを再生成しました" | "TTS regenerated" |
| `tts.regenerateError` | "재생성에 실패했습니다. 다시 시도해 주세요." | "再生成に失敗しました。もう一度お試しください。" | "Regeneration failed. Please try again." |

**No locale file changes needed.** The hook was the only place these translations were missing.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Vitest ^4.0.18 |
| Config file | `apps/admin/vitest.config.ts` |
| Quick run command | `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts` |
| Full suite command | `cd apps/admin && pnpm vitest run` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| I18N-04 | No CJK in .ts/.tsx source files | unit (file scan) | `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts` | Yes (modify existing) |
| I18N-05 | Toast uses locale-aware string | manual smoke / verified by I18N-04 | same as above | Yes |

### Sampling Rate
- **Per task commit:** `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts`
- **Per wave merge:** `cd apps/admin && pnpm vitest run`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements. `hardcoded-strings.test.ts` exists and will be modified in-place.

## Open Questions

1. **Nested vs flat key naming (Claude's Discretion)**
   - What we know: CONTEXT.md D-02/D-03 specified `regenerate.success` / `regenerate.error` (nested dot-notation). Locale files have `regenerateSuccess` / `regenerateError` (flat camelCase).
   - What's unclear: Whether to add new nested keys or reuse flat keys.
   - Recommendation: Use existing flat keys `t('regenerateSuccess')` and `t('regenerateError')`. No locale file edits needed. Avoids key duplication. If the planner decides nested keys are required per D-03, add `regenerate: { success: "...", error: "..." }` to all three locale files.

## Sources

### Primary (HIGH confidence)
- Direct file inspection: `apps/admin/src/hooks/use-tts-player.ts` — exact lines 78/81 confirmed
- Direct file inspection: `apps/admin/src/__tests__/hardcoded-strings.test.ts` — current scan logic confirmed
- Direct file inspection: `apps/admin/messages/ko.json`, `ja.json`, `en.json` — existing tts namespace keys confirmed

### Secondary (MEDIUM confidence)
- `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` — Phase 7 pattern for useTranslations in client component/hook

## Project Constraints (from CLAUDE.md)

- TypeScript strict mode — no `any`, no unchecked indexed access
- kebab-case file names (already compliant — file names unchanged)
- `'use client'` directive required for hooks using React state/effects (already present in use-tts-player.ts)
- Commit only after lint passes: `pnpm lint` from repo root
- Test files in `__tests__/` pattern (already compliant)
- Named exports preferred (already compliant)
- Codex cross-validation required before committing feature/bug commits

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already installed, confirmed by package.json
- Architecture: HIGH — exact file content read, patterns verified from Phase 7
- Pitfalls: HIGH — derived directly from reading the actual code to be changed
- Key inventory: HIGH — read all three locale files directly

**Research date:** 2026-04-02
**Valid until:** N/A — no external dependencies, purely internal code change
