# Phase 7: i18n Completion & Accessibility - Research

**Researched:** 2026-04-01
**Domain:** next-intl i18n, ARIA accessibility, React/Next.js
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 카테고리 라벨(TRAVEL→旅行 등)은 messages/{locale}.json에 매핑하고 프론트에서 `t(`category.${value}`)` 로 변환한다 (서버 API 수정 불필요)
- **D-02:** audit-timeline 시간 표현(たった今, N分前 등)은 next-intl ICU MessageFormat 패턴으로 전환한다
- **D-03:** Zod 에러 메시지, toast 메시지, 에러 표시 등 모든 사용자 노출 문자열을 i18n 키로 전환한다 (console.log 등 개발자용 제외)
- **D-04:** 폼 라벨(単語, 読み方, 例文 등), placeholder('[\"選択肢1\"]' 등) 모두 i18n 전환한다
- **D-05:** i18n 네임스페이스는 기존 패턴(nav, auth, table, page, empty, error, review, tts) 유지하며 새 키를 추가한다 (category, validation, time, form 등)
- **D-06:** 요구사항 4가지(A11Y-01~04)만 구현한다. 추가 접근성 작업은 별도 phase.
- **D-07:** skip link는 sr-only 스타일로 숨기고 Tab 포커스 시에만 표시하는 표준 패턴 사용
- **D-08:** skip link 대상은 main 콘텐츠 영역 (`id="main-content"`)
- **D-09:** aria-label도 locale에 맞게 i18n 키로 전환한다 (기존 하드코딩 일본어 aria-label 포함)
- **D-10:** src/ 내 .tsx 파일에서 일본어/한국어 문자 패턴을 grep으로 검사하는 CI 스크립트 추가 (locale-switcher 등 예외 파일 allowlist 관리)
- **D-11:** ko.json, ja.json, en.json 3개 메시지 파일의 키 집합 일치 검사 스크립트/테스트 추가

### Claude's Discretion

- 번역 검증 스크립트의 구체적 구현 방식 (shell script vs vitest)
- i18n 키 네이밍 세부 규칙
- 접근성 구현의 기술적 세부사항 (컴포넌트 구조 등)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| I18N-04 | 모든 UI 문자열이 i18n 키를 통해 번역된다 (하드코딩 일본어 없음) | Hardcoded string inventory below; new message keys identified for category, validation, time namespaces |
| I18N-05 | locale 전환 시 모든 텍스트가 선택된 언어로 표시된다 | next-intl already installed; 3 locale files must stay in sync; key parity script covers this |
| A11Y-01 | 사이드바 활성 항목에 aria-current="page"가 설정된다 | SidebarNavItem already computes `isActive`; one-line aria-current addition |
| A11Y-02 | 메인 콘텐츠로 건너뛰는 skip link가 있다 | AdminLayout is the insertion point; sr-only + focus:not-sr-only Tailwind pattern |
| A11Y-03 | nav, aside, main에 의미 있는 aria-label이 있다 | Sidebar `<aside>` and AdminLayout `<main>` need aria-label from i18n |
| A11Y-04 | 검색 입력에 명시적 label이 있다 | FilterBar `<Input>` is unlabeled; associate via htmlFor/id or wrap in `<label>` |
</phase_requirements>

---

## Summary

Phase 7 is a surgical cleanup of two categories: (1) hardcoded CJK strings scattered across 8 source files, and (2) four targeted ARIA additions. The existing next-intl infrastructure is mature and complete — `useTranslations()` and `getTranslations()` are used throughout, and all three locale files (`ko.json`, `ja.json`, `en.json`) share a consistent key structure at 177 lines each.

The hardcoded strings break down into four groups: (a) table column headers in list pages (using the `Column.header` string field), (b) toast/error messages in detail page handlers, (c) Zod schema error messages, and (d) inline placeholder text. The `audit-timeline.tsx` `formatRelativeTime` function requires a special approach — the existing pure-JS function must be replaced by next-intl ICU MessageFormat with plural support.

Accessibility changes are minimal: `SidebarNavItem` already computes `isActive` but does not output `aria-current`; `AdminLayout` uses a bare `<main>` and `<aside>` (via `Sidebar`) with no landmark labels; `FilterBar` has an unlabeled `<Input>` for search. None of these require architectural changes.

**Primary recommendation:** Implement in two waves. Wave 1: i18n key additions to all three locale files + component updates for hardcoded strings. Wave 2: accessibility additions + validation scripts.

---

## Hardcoded String Inventory (Complete)

This is the full ground-truth list of hardcoded CJK strings found in source files (grep-verified). All must become i18n keys.

### Group A: Table column headers (list pages)

These `header` strings are plain JS strings passed into the `Column<T>` type. The `ContentTable` component renders `col.header` directly — no translation hook is present in that render path. The column definitions must call `useTranslations` in the page component and pass translated strings.

| File | Hardcoded value | Proposed key |
|------|-----------------|--------------|
| `vocabulary/page.tsx` | `'単語'` | `table.col.word` |
| `vocabulary/page.tsx` | `'読み方'` | `table.col.reading` |
| `vocabulary/page.tsx` | `'意味'` | `table.col.meaningKo` |
| `vocabulary/page.tsx` | `'ステータス'` (×2 files) | `table.col.status` |
| `vocabulary/page.tsx` | `'更新日'` (×4 files) | `table.col.updatedAt` |
| `grammar/page.tsx` | `'パターン'` | `table.col.pattern` |
| `grammar/page.tsx` | `'説明'` | `table.col.explanation` |
| `quiz/page.tsx` | `'問題文'` | `table.col.sentence` |
| `quiz/page.tsx` | `'種類'` | `table.col.quizType` |
| `conversation/page.tsx` | `'タイトル'` | `table.col.title` |
| `conversation/page.tsx` | `'カテゴリ'` | `table.col.category` |

### Group B: Toast and error messages (detail pages)

All four detail pages share the same two patterns: `toast.info('変更がありません')` and `<div>データの読み込みに失敗しました</div>`.

| File | Hardcoded value | Proposed key |
|------|-----------------|--------------|
| `vocabulary/[id]/page.tsx` | `'変更がありません'` | `edit.noChanges` |
| `vocabulary/[id]/page.tsx` | `データの読み込みに失敗しました` | `error.failedToLoad` (exists) |
| `grammar/[id]/page.tsx` | same two | same keys |
| `quiz/[id]/page.tsx` | same two | same keys |
| `conversation/[id]/page.tsx` | `'変更がありません'` | `edit.noChanges` |
| `conversation/[id]/page.tsx` | `データの読み込みに失敗しました` | `error.failedToLoad` (exists) |
| `conversation/[id]/page.tsx` | `placeholder='["表現1","表現2"]'` | `edit.placeholder.keyExpressions` |

Note: `error.failedToLoad` already exists in all three locale files with correct text. The inline JSX `<div>データの読み込みに失敗しました</div>` simply needs to call `t('error.failedToLoad')`.

### Group C: Zod schema error messages

These are inside `z.refine()` message strings — they appear in form validation errors.

| File | Hardcoded value | Proposed key |
|------|-----------------|--------------|
| `grammar/[id]/page.tsx` | `'有効なJSON配列を入力してください'` | `validation.invalidJsonArray` |
| `quiz/[id]/page.tsx` | `'有効なJSON配列を入力してください'` | `validation.invalidJsonArray` (same) |
| `conversation/[id]/page.tsx` | `'有効なJSON配列を入力してください'` | `validation.invalidJsonArray` (same) |

**Important:** Zod schemas are defined at module level (outside component). `useTranslations()` cannot be called outside React components. The solution is to move the schema definition inside the component, or use a schema factory function that accepts the translated string as a parameter.

### Group D: Inline placeholder text

| File | Hardcoded value | Proposed key |
|------|-----------------|--------------|
| `quiz/[id]/page.tsx` (ClozeForm) | `'["選択肢1","選択肢2"]'` | `edit.placeholder.options` |
| `quiz/[id]/page.tsx` (SentenceArrangeForm) | `'["トークン1","トークン2"]'` | `edit.placeholder.tokens` |

Note: `grammar/[id]/page.tsx` has `placeholder='[{"ja": "例文", "ko": "예문"}]'` — this is a structural hint, not a CJK string per se. The grep did not flag it; per D-03, developer-hint strings without user-facing CJK characters are out of scope.

### Group E: Hardcoded aria-labels in content-table.tsx

| Location | Current value | Proposed key |
|----------|---------------|--------------|
| `content-table.tsx:177` | `aria-label="全て選択"` | `table.selectAll` |
| `content-table.tsx:275` | `aria-label={`行 ${item.id} を選択`}` | `table.selectRow` (with `{id}` param) |

`ContentTable` is a client component using `useTranslations` — this is straightforward.

### Group F: キャンセル in reject-reason-dialog.tsx

| Location | Current value | Proposed key |
|----------|---------------|--------------|
| `reject-reason-dialog.tsx:70` | `キャンセル` | `review.cancel` |

### Group G: audit-timeline.tsx relative time

The `formatRelativeTime` function returns hardcoded Japanese strings. Decision D-02 requires ICU MessageFormat conversion.

Current behavior:
```
< 1 min  → 'たった今'
N min    → `${N}分前`
N hours  → `${N}時間前`
N days   → `${N}日前`
```

This requires 4 new ICU-style keys under a `time` namespace:
```json
"time": {
  "justNow": "たった今",
  "minutesAgo": "{n, plural, one {1分前} other {{n}分前}}",
  "hoursAgo": "{n, plural, one {1時間前} other {{n}時間前}}",
  "daysAgo": "{n, plural, one {1日前} other {{n}日前}}"
}
```

The `formatRelativeTime` function must become a React component or hook that calls `useTranslations('time')`, since ICU plural formatting requires the `t()` function.

### Group H: SCENARIO_CATEGORIES labels in conversation/page.tsx

```typescript
const SCENARIO_CATEGORIES = [
  { value: 'TRAVEL', label: '旅行' },
  { value: 'SHOPPING', label: 'ショッピング' },
  ...
];
```

Per D-01, these labels come from a new `category` namespace in messages files. The `FilterBar` receives `categories` prop as `{ value, label }[]` — the page component must transform this array using `t()`.

Proposed keys:
```json
"category": {
  "TRAVEL": "旅行",
  "SHOPPING": "ショッピング",
  "RESTAURANT": "レストラン",
  "BUSINESS": "ビジネス",
  "DAILY_LIFE": "日常生活",
  "EMERGENCY": "緊急",
  "TRANSPORTATION": "交通",
  "HEALTHCARE": "医療"
}
```

The `conversation/page.tsx` column render for category also uses `cat?.label ?? item.category` — same fix applies there.

---

## Standard Stack

### Core (already installed, no new packages needed)

| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `next-intl` | in use | i18n translations, ICU format | `useTranslations`, `getTranslations` already wired |
| Tailwind CSS | in use | `sr-only` utility for skip link | `focus:not-sr-only focus:absolute` pattern |
| React / Next.js 16.1 | in use | App Router, Server Components | `getTranslations` for server, `useTranslations` for client |

No new packages required for this phase.

### Validation Scripts (Claude's Discretion — recommend Vitest)

The two validation scripts (D-10, D-11) can be shell scripts or Vitest tests. Given the existing `vitest.config.ts` in `apps/admin/`, Vitest is the better choice:

- Already configured with `jsdom` environment and `src/**/*.test.{ts,tsx}` glob
- Key-parity test can import the three JSON files and compare key sets
- Hardcoded string check can use Node.js `fs` to read source files and match regex

---

## Architecture Patterns

### Pattern 1: Zod schema with translated error message

**Problem:** Zod schemas at module level cannot call `useTranslations()`.

**Solution:** Define the schema inside the component or as a factory function:

```typescript
// Source: pattern derived from next-intl + react-hook-form docs
function useGrammarSchema() {
  const t = useTranslations('validation');
  return z.object({
    exampleSentences: z
      .string()
      .optional()
      .refine(
        (val) => { /* same logic */ },
        { message: t('invalidJsonArray') }
      ),
  });
}

// In component:
const schema = useGrammarSchema();
const { register, handleSubmit, ... } = useForm({
  resolver: zodResolver(schema),
  // ...
});
```

Note: `zodResolver` accepts the schema at `useForm` call time, so a hook that returns a schema works correctly. The schema changes when locale changes because `useTranslations` returns locale-aware translations.

### Pattern 2: Table column headers with translations

**Problem:** `Column<T>.header` is a plain `string`. The column array is defined inside the component function but currently uses hardcoded strings.

**Solution:** Call `useTranslations('table')` in the list page component and reference keys in the column definitions:

```typescript
function VocabularyContent() {
  const t = useTranslations('table');
  const tCol = useTranslations('table'); // or separate namespace

  const columns: Column<VocabularyItem>[] = [
    { key: 'word', header: tCol('col.word'), width: '15%' },
    { key: 'reading', header: tCol('col.reading'), width: '15%' },
    // ...
  ];
}
```

The `Column.header` type is already `string`, so no type changes needed.

### Pattern 3: audit-timeline relative time via useTranslations

**Problem:** `formatRelativeTime` is a pure function called in JSX. ICU plural format requires `t()`.

**Solution:** Replace `formatRelativeTime` with a hook or inline translation call:

```typescript
// In AuditTimeline component body:
const tTime = useTranslations('time');

function formatRelativeTime(dateStr: string): string {
  const diffMin = Math.floor((Date.now() - new Date(dateStr).getTime()) / 60_000);
  if (diffMin < 1) return tTime('justNow');
  if (diffMin < 60) return tTime('minutesAgo', { n: diffMin });
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return tTime('hoursAgo', { n: diffH });
  return tTime('daysAgo', { n: Math.floor(diffH / 24) });
}
```

`AuditTimeline` is already a React component (not a pure function), so calling `useTranslations` at its top level is valid.

### Pattern 4: Skip link in AdminLayout

**Problem:** `AdminLayout` renders `<main className="flex-1 overflow-y-auto p-8">` with no landmark labels or skip mechanism.

**Solution:** Add skip link before sidebar, add `id` to `<main>`, add `aria-label` attributes. Since `AdminLayout` is a server component, use `getTranslations`:

```typescript
// apps/admin/src/app/(admin)/layout.tsx
export default async function AdminLayout({ children }) {
  const user = await requireReviewer();
  const locale = await getLocale();
  const t = await getTranslations('a11y');

  return (
    <div className="flex h-screen overflow-hidden">
      {/* Skip link — visually hidden until focused */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-background focus:px-4 focus:py-2 focus:text-sm focus:shadow"
      >
        {t('skipToMain')}
      </a>
      <Sidebar user={user} locale={locale} />
      <main
        id="main-content"
        aria-label={t('mainContent')}
        className="flex-1 overflow-y-auto p-8"
      >
        {children}
      </main>
    </div>
  );
}
```

The `<aside>` landmark lives in `sidebar.tsx`. Add `aria-label={t('sidebar')}` (using `getTranslations` already called there) to the `<aside>` element.

### Pattern 5: aria-current on SidebarNavItem

`SidebarNavItem` already computes `isActive`. Add `aria-current`:

```typescript
<Link
  href={href}
  aria-current={isActive ? 'page' : undefined}
  className={cn(...)}
>
```

`aria-current={undefined}` removes the attribute from the DOM entirely — this is the correct pattern (not `aria-current="false"`).

### Pattern 6: Explicit label for search input in FilterBar

`FilterBar` has `<Input type="search" ... />` with no associated label. Add a visually hidden label:

```typescript
// Option A: sr-only label element (preferred — explicit association)
<label htmlFor="filter-search" className="sr-only">
  {t('searchLabel')}
</label>
<Input
  id="filter-search"
  type="search"
  placeholder={t('searchPlaceholder')}
  ...
/>
```

This requires adding `searchLabel` to the `filter` namespace (already has `searchPlaceholder`).

### Anti-Patterns to Avoid

- **aria-current="false":** Use `aria-current={isActive ? 'page' : undefined}` — the attribute should be absent when inactive, not set to "false"
- **Zod schema at module level with t() call:** `useTranslations` is a React hook, cannot be called at module scope
- **Skipping ICU plural for time strings:** Simple template literals `${n}分前` don't localize correctly in non-Japanese locales; use ICU `{n, plural, ...}` or per-count keys
- **New i18n namespaces for minor additions:** Extend existing namespaces per D-05; only add `category`, `validation`, `time`, `a11y` as new namespaces where no existing namespace fits
- **Hardcoding `lang="ja"` in aria-labels:** All aria-labels must use `t()` per D-09

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ICU plural formatting | Custom plural logic | next-intl ICU `{n, plural, ...}` | next-intl handles plural rules per locale automatically |
| Locale-aware date formatting | Custom `toLocaleDateString` with hardcoded `'ja-JP'` | next-intl `useFormatter()` or leave as-is | The `toLocaleDateString('ja-JP')` in list pages is a DATE, not a string to i18n — it falls outside phase scope since it displays data, not UI chrome |
| Key parity validation | Custom recursive diff algorithm | Simple `JSON.stringify(Object.keys(...).sort())` comparison | Flat JSON key sets are trivially comparable |

---

## New i18n Keys Required

The following keys must be added to all three locale files (`ko.json`, `ja.json`, `en.json`) identically in structure.

### `table.col` namespace extension

```json
"table": {
  "col": {
    "word": "단어",
    "reading": "읽기",
    "meaningKo": "의미",
    "pattern": "패턴",
    "explanation": "설명",
    "sentence": "문제문",
    "quizType": "종류",
    "title": "제목",
    "category": "카테고리",
    "status": "상태",
    "updatedAt": "수정일"
  },
  "selectAll": "전체 선택",
  "selectRow": "{id} 행 선택"
}
```

### `edit` namespace extension

```json
"edit": {
  "noChanges": "변경사항이 없습니다",
  "placeholder": {
    "options": "[\"선택지1\",\"선택지2\"]",
    "keyExpressions": "[\"표현1\",\"표현2\"]",
    "tokens": "[\"토큰1\",\"토큰2\"]"
  }
}
```

### `validation` namespace (new)

```json
"validation": {
  "invalidJsonArray": "유효한 JSON 배열을 입력하세요"
}
```

### `time` namespace (new)

```json
"time": {
  "justNow": "방금 전",
  "minutesAgo": "{n}분 전",
  "hoursAgo": "{n}시간 전",
  "daysAgo": "{n}일 전"
}
```

### `category` namespace (new)

```json
"category": {
  "TRAVEL": "여행",
  "SHOPPING": "쇼핑",
  "RESTAURANT": "레스토랑",
  "BUSINESS": "비즈니스",
  "DAILY_LIFE": "일상생활",
  "EMERGENCY": "긴급",
  "TRANSPORTATION": "교통",
  "HEALTHCARE": "의료"
}
```

### `a11y` namespace (new)

```json
"a11y": {
  "skipToMain": "메인 콘텐츠로 건너뛰기",
  "mainContent": "메인 콘텐츠",
  "sidebar": "내비게이션",
  "navigation": "사이드바 내비게이션"
}
```

### `review.cancel` extension

```json
"review": {
  "cancel": "취소"
}
```

### `filter.searchLabel` extension

```json
"filter": {
  "searchLabel": "검색"
}
```

---

## Common Pitfalls

### Pitfall 1: Zod schema outside React component scope

**What goes wrong:** `useTranslations()` called at module level throws an error because it's a React hook that requires a component context.

**Why it happens:** All four detail pages define schemas at module level for conciseness. Moving them inside the component function is necessary.

**How to avoid:** Move `z.object({ ... })` inside the component function OR create a `useSchema()` hook that calls `useTranslations` and returns the schema.

**Warning signs:** TypeScript/ESLint will not flag this — it only errors at runtime.

### Pitfall 2: `aria-current="false"` instead of omitting the attribute

**What goes wrong:** Screen readers announce "false, link" for every inactive nav item, making navigation verbose and confusing.

**How to avoid:** Use `aria-current={isActive ? 'page' : undefined}`. React omits attributes with `undefined` value from the DOM.

### Pitfall 3: Key parity drift between locale files

**What goes wrong:** A key is added to `ko.json` but forgotten in `en.json`, causing runtime errors or silent fallbacks.

**How to avoid:** The D-11 key parity test catches this before merge. Add keys to all three files in the same commit.

### Pitfall 4: `conversation/page.tsx` category render path

The `column.render` for category uses `cat?.label ?? item.category`. After i18n conversion, `SCENARIO_CATEGORIES` labels become translated strings from `t()` — the `FilterBar` prop also passes this same array. Both the column definition and the `FilterBar` categories prop must be updated in the same component refactor to avoid inconsistency.

### Pitfall 5: ICU plural format vs simple string interpolation

**What goes wrong:** Using `{n}분 전` (next-intl interpolation) works fine in Korean/Japanese, but English requires different plural forms (`1 minute ago` vs `N minutes ago`).

**How to avoid:** Use ICU plural syntax:
```json
"minutesAgo": "{n, plural, one {1 minute ago} other {{n} minutes ago}}"
```
For Korean/Japanese, plural rules collapse to `other`, so the result is identical. For English, it produces grammatically correct output.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Vitest 4.x |
| Config file | `apps/admin/vitest.config.ts` |
| Quick run command | `cd apps/admin && pnpm vitest run src/__tests__` |
| Full suite command | `cd apps/admin && pnpm vitest run` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| I18N-04 | No CJK strings in .tsx source files | Script (grep) | `node scripts/check-hardcoded-strings.mjs` | Wave 0 |
| I18N-04 | No CJK strings in .tsx source files | Vitest | `pnpm vitest run src/__tests__/hardcoded-strings.test.ts` | Wave 0 |
| I18N-05 | ko/ja/en locale files have identical key structure | Vitest | `pnpm vitest run src/__tests__/locale-key-parity.test.ts` | Wave 0 |
| A11Y-01 | SidebarNavItem renders aria-current="page" when active | unit | `pnpm vitest run src/__tests__/sidebar-nav-item.test.tsx` | Exists — extend |
| A11Y-02 | Skip link exists in admin layout output | unit | `pnpm vitest run src/__tests__/layout.test.tsx` | Exists — extend |
| A11Y-03 | aside/main have aria-label attributes | unit | `pnpm vitest run src/__tests__/layout.test.tsx` | Exists — extend |
| A11Y-04 | Search input has associated label element | unit | `pnpm vitest run src/__tests__/filter-bar.test.tsx` | Wave 0 |

### Sampling Rate

- **Per task commit:** `cd apps/admin && pnpm vitest run src/__tests__`
- **Per wave merge:** `cd apps/admin && pnpm vitest run`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `src/__tests__/hardcoded-strings.test.ts` — covers I18N-04 (reads .tsx files, asserts no CJK regex match outside allowlist)
- [ ] `src/__tests__/locale-key-parity.test.ts` — covers I18N-05 (imports all three locale JSONs, deep-compares key structure)
- [ ] `src/__tests__/filter-bar.test.tsx` — covers A11Y-04 (renders FilterBar, asserts label[for] linked to search input)

Existing test files that need extension:
- `src/__tests__/sidebar-nav-item.test.tsx` — add test for `aria-current="page"` on active item
- `src/__tests__/layout.test.tsx` — add tests for skip link presence and aria-label on aside/main

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — pure code/config changes to existing Next.js admin app)

---

## Code Examples

### Skip link pattern (Tailwind sr-only + focus reveal)

```typescript
// Source: WCAG 2.1 SC 2.4.1 + Tailwind CSS sr-only docs
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-background focus:px-4 focus:py-2 focus:text-sm focus:shadow"
>
  {t('skipToMain')}
</a>
```

### aria-current on nav link

```typescript
// Source: ARIA spec — aria-current values: page | step | location | date | time | true | false
<Link
  href={href}
  aria-current={isActive ? 'page' : undefined}
  className={cn(...)}
>
```

### next-intl ICU plural in JSON

```json
// Source: next-intl docs — ICU MessageFormat
"minutesAgo": "{n, plural, one {1 minute ago} other {{n} minutes ago}}"
```

### Zod schema inside component (hook pattern)

```typescript
// Pattern: schema factory hook — avoids module-level hook call
function useConversationSchema() {
  const t = useTranslations('validation');
  return useMemo(() =>
    z.object({
      keyExpressions: z.string().optional().refine(
        (val) => { if (!val || !val.trim()) return true; try { return Array.isArray(JSON.parse(val)); } catch { return false; } },
        { message: t('invalidJsonArray') }
      ),
    }),
    [t]
  );
}
```

### Locale key parity test

```typescript
// Source: Vitest pattern with JSON imports
import ko from '../../messages/ko.json';
import ja from '../../messages/ja.json';
import en from '../../messages/en.json';

function flatKeys(obj: object, prefix = ''): string[] {
  return Object.entries(obj).flatMap(([k, v]) =>
    typeof v === 'object' && v !== null
      ? flatKeys(v as object, prefix ? `${prefix}.${k}` : k)
      : [prefix ? `${prefix}.${k}` : k]
  );
}

describe('locale key parity', () => {
  it('ko, ja, en have identical key sets', () => {
    const koKeys = flatKeys(ko).sort();
    const jaKeys = flatKeys(ja).sort();
    const enKeys = flatKeys(en).sort();
    expect(jaKeys).toEqual(koKeys);
    expect(enKeys).toEqual(koKeys);
  });
});
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Hardcoded Japanese strings in JSX | next-intl `useTranslations()` | Required for I18N-04/05 |
| Pure JS relative time function | next-intl ICU plural keys | Correct pluralization per locale |
| Module-level Zod schema | In-component schema with translated messages | Enables locale-aware validation errors |

---

## Open Questions

1. **`toLocaleDateString('ja-JP')` in list pages**
   - What we know: Four list pages call `new Date(...).toLocaleDateString('ja-JP')` for the `更新日` column. This is hardcoded to Japanese locale.
   - What's unclear: The updated-at column displays data, not UI chrome. The CONTEXT.md decisions do not mention date formatting.
   - Recommendation: Leave as-is for this phase. The `更新日` column header will be i18n-converted. The date format is a data display concern outside I18N-04/05 scope. Flag for future enhancement.

2. **`grammar/[id]/page.tsx` placeholder `[{"ja": "例文", "ko": "예문"}]`**
   - What we know: This placeholder contains Korean/Japanese characters but is a structural hint showing the JSON schema shape, not a user-facing label.
   - Recommendation: Leave as-is per D-03 (developer-facing strings exempt). Confirm with project owner if needed.

---

## Project Constraints (from CLAUDE.md)

| Constraint | Impact on Phase |
|------------|-----------------|
| TypeScript strict mode + `any` forbidden | All new keys/translations must be properly typed; next-intl type inference already handles this |
| kebab-case filenames | New test files: `hardcoded-strings.test.ts`, `locale-key-parity.test.ts`, `filter-bar.test.tsx` |
| `'use client'` required for hooks | `AuditTimeline`, `FilterBar`, list pages already have `'use client'` — no change needed for `useTranslations` additions |
| Commit before lint check | Run `pnpm lint` in `apps/admin` before each commit |
| No new i18n namespaces unless needed | Add only: `category`, `validation`, `time`, `a11y` — all fill genuine gaps |
| Codex cross-verification before feature commits | All wave-final commits require Codex review |
| DDL via Alembic only | Phase 7 has no DB changes — not applicable |

---

## Sources

### Primary (HIGH confidence)

- Direct source code inspection: `apps/admin/src/` — 15+ files read, hardcoded string inventory is grep-verified
- `apps/admin/messages/*.json` — all three locale files read in full; key structure confirmed
- `apps/admin/vitest.config.ts` — test infrastructure confirmed

### Secondary (MEDIUM confidence)

- ARIA specification (aria-current values: `page | step | location | date | time | true | false`) — well-established standard
- Tailwind CSS `sr-only` / `focus:not-sr-only` pattern — documented in Tailwind CSS utility reference
- next-intl ICU MessageFormat plural syntax — standard ICU format supported by next-intl

### Tertiary (LOW confidence)

None — all findings are based on direct codebase inspection or established standards.

---

## Metadata

**Confidence breakdown:**
- Hardcoded string inventory: HIGH — grep-verified against all source files
- i18n patterns: HIGH — based on existing working patterns in codebase
- Accessibility patterns: HIGH — based on ARIA spec and WCAG 2.1 standards
- Test architecture: HIGH — existing vitest infrastructure confirmed

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable domain — Next.js/next-intl APIs unlikely to change)
