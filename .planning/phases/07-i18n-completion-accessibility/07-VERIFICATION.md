---
phase: 07-i18n-completion-accessibility
verified: 2026-04-01T09:15:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
---

# Phase 7: i18n Completion + Accessibility Verification Report

**Phase Goal:** UI의 모든 텍스트가 선택된 언어로 표시되고, 스크린 리더와 키보드 사용자가 어드민을 탐색할 수 있다
**Verified:** 2026-04-01T09:15:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                  | Status     | Evidence                                                                                       |
|----|----------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------|
| 1  | ko.json, ja.json, en.json have identical key structures (173 keys each)               | ✓ VERIFIED | node parity check passes; `category`, `validation`, `time`, `a11y` namespaces present in all 3 |
| 2  | Locale key parity test passes                                                          | ✓ VERIFIED | `vitest run locale-key-parity.test.ts` — 1 test passed                                        |
| 3  | No hardcoded CJK strings remain in .tsx source files (outside allowlist)              | ✓ VERIFIED | `vitest run hardcoded-strings.test.ts` — 1 test passed (zero violations)                      |
| 4  | Category labels in conversation page render via `tCat('VALUE')` not hardcoded         | ✓ VERIFIED | `conversation/page.tsx:26` — `].map((key) => ({ value: key, label: tCat(key) }))`             |
| 5  | Audit timeline relative time uses next-intl ICU format, not hardcoded Japanese        | ✓ VERIFIED | `audit-timeline.tsx:36` — `useTranslations('time')`, passed to pure `formatRelativeTime()`    |
| 6  | Active sidebar nav item has `aria-current='page'` attribute                           | ✓ VERIFIED | `sidebar-nav-item.tsx:24` — `aria-current={isActive ? 'page' : undefined}`                    |
| 7  | Pressing Tab reveals a skip link targeting `#main-content`                            | ✓ VERIFIED | `layout.tsx:17-20` — `<a href="#main-content" className="sr-only focus:not-sr-only ...>`      |
| 8  | Screen readers can identify aside, nav, and main landmarks by aria-labels             | ✓ VERIFIED | `sidebar.tsx:59` aside label; `sidebar-nav-with-badges.tsx:34` nav label; `layout.tsx:25` main label — all via `a11y.*` i18n keys |

**Score:** 8/8 truths verified

---

### Required Artifacts

| Artifact                                              | Expected                                                      | Status     | Details                                                         |
|-------------------------------------------------------|---------------------------------------------------------------|------------|-----------------------------------------------------------------|
| `apps/admin/messages/ko.json`                         | Korean translations with category, validation, time, a11y     | ✓ VERIFIED | 173 keys, all new namespaces confirmed                          |
| `apps/admin/messages/ja.json`                         | Japanese translations, identical key structure                | ✓ VERIFIED | Key parity confirmed — 173 keys                                 |
| `apps/admin/messages/en.json`                         | English translations, identical key structure                 | ✓ VERIFIED | Key parity confirmed; `time.minutesAgo` has ICU plural syntax   |
| `apps/admin/src/__tests__/locale-key-parity.test.ts`  | Vitest importing all 3 locale JSONs, asserting key parity     | ✓ VERIFIED | Contains `flatKeys`, imports `ko/ja/en`, test passes            |
| `apps/admin/src/__tests__/hardcoded-strings.test.ts`  | Vitest scanning .tsx for CJK outside allowlist                | ✓ VERIFIED | Contains `CJK_PATTERN`, `locale-switcher.tsx` in ALLOWLIST, passes |
| `apps/admin/src/app/(admin)/vocabulary/page.tsx`      | Translated column headers via `t('col.*')`                    | ✓ VERIFIED | `t('col.word')`, `t('col.reading')`, etc. confirmed             |
| `apps/admin/src/app/(admin)/conversation/page.tsx`    | Category labels via `tCat()`, no hardcoded Japanese           | ✓ VERIFIED | `tCat(key)` map pattern; `tCat(item.category)` in render        |
| `apps/admin/src/components/content/audit-timeline.tsx`| Relative time via `useTranslations('time')` ICU format        | ✓ VERIFIED | `tTime` passed to pure `formatRelativeTime()`, line 36 + 101    |
| `apps/admin/src/components/content/content-table.tsx` | Translated aria-labels for checkboxes                         | ✓ VERIFIED | `tTable('selectAll')` line 179; `tTable('selectRow', ...)` line 277 |
| `apps/admin/src/components/content/reject-reason-dialog.tsx` | Cancel via `t('review.cancel')`                      | ✓ VERIFIED | Line 70 — `{t('cancel')}` with `useTranslations('review')`     |
| `apps/admin/src/components/layout/sidebar-nav-item.tsx` | `aria-current='page'` on active Link                        | ✓ VERIFIED | Line 24 — `aria-current={isActive ? 'page' : undefined}`        |
| `apps/admin/src/app/(admin)/layout.tsx`               | Skip link + `id='main-content'` + `aria-label` on main        | ✓ VERIFIED | Lines 12, 17, 24, 25 all confirmed                              |
| `apps/admin/src/components/layout/sidebar.tsx`        | `aria-label` on `<aside>`                                     | ✓ VERIFIED | Line 59 — `aria-label={tA11y('sidebarNav')}`                    |
| `apps/admin/src/components/layout/sidebar-nav-with-badges.tsx` | `aria-label` on `<nav>`                             | ✓ VERIFIED | Line 34 — `aria-label={tA11y('primaryNav')}`                    |
| `apps/admin/src/components/content/filter-bar.tsx`    | `sr-only` label linked to search input via `htmlFor`/`id`     | ✓ VERIFIED | Lines 72 (`htmlFor="search-input"`) and 76 (`id="search-input"`) |
| `apps/admin/src/__tests__/filter-bar.test.tsx`        | Test verifying search input has associated label              | ✓ VERIFIED | `getByLabelText('Search')` + `sr-only` assertions pass          |

---

### Key Link Verification

| From                                     | To                          | Via                                          | Status     | Details                                                            |
|------------------------------------------|-----------------------------|----------------------------------------------|------------|--------------------------------------------------------------------|
| `locale-key-parity.test.ts`              | `messages/*.json`           | JSON import + deep key comparison            | ✓ WIRED    | `import ko from '../../messages/ko.json'` confirmed; test passes   |
| `vocabulary/page.tsx`                    | `messages/*.json`           | `useTranslations('table')` for column headers | ✓ WIRED   | `t('col.word')` etc. confirmed at lines 24, 29, 34, 51, 62        |
| `audit-timeline.tsx`                     | `messages/*.json`           | `useTranslations('time')` for relative time  | ✓ WIRED    | `tTime('justNow'|'minutesAgo'|'hoursAgo'|'daysAgo')` lines 27-31  |
| `layout.tsx`                             | `messages/*.json`           | `getTranslations('a11y')` for skip link      | ✓ WIRED    | `import { getTranslations } from 'next-intl/server'`, `t('skipToMain')` |
| `sidebar.tsx`                            | `messages/*.json`           | `getTranslations` for aside `aria-label`     | ✓ WIRED    | `tA11y('sidebarNav')` on `<aside>` element                        |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase produces translation infrastructure and ARIA attribute additions. No dynamic data rendering from a remote data source. All wired artifacts produce real i18n output via next-intl from static JSON locale files.

---

### Behavioral Spot-Checks

| Behavior                                         | Command / Check                                                                 | Result  | Status   |
|--------------------------------------------------|---------------------------------------------------------------------------------|---------|----------|
| Locale key parity passes                         | `vitest run src/__tests__/locale-key-parity.test.ts`                           | 1 pass  | ✓ PASS   |
| Hardcoded CJK detection passes (zero violations) | `vitest run src/__tests__/hardcoded-strings.test.ts`                           | 1 pass  | ✓ PASS   |
| aria-current tests pass                          | `vitest run src/__tests__/sidebar-nav-item.test.tsx`                           | 5 pass  | ✓ PASS   |
| Skip link + landmark tests pass                  | `vitest run src/__tests__/layout.test.tsx`                                     | 6 pass, 3 todo | ✓ PASS |
| Search label accessibility test passes           | `vitest run src/__tests__/filter-bar.test.tsx`                                 | 2 pass  | ✓ PASS   |
| Phase commits present in git log                 | `git log --oneline -10` — commits cae70e9, 0891ee3, 6534dd7, e534c34, 6fe7f05, 1d38960 | all found | ✓ PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                        | Status       | Evidence                                                           |
|-------------|-------------|--------------------------------------------------------------------|--------------|--------------------------------------------------------------------|
| I18N-04     | 07-02       | 모든 UI 문자열이 i18n 키를 통해 번역된다 (하드코딩 일본어 없음)   | ✓ SATISFIED  | `hardcoded-strings.test.ts` passes; all CJK strings replaced       |
| I18N-05     | 07-01, 07-02 | locale 전환 시 모든 텍스트가 선택된 언어로 표시된다              | ✓ SATISFIED  | All text uses `t()` from 3-locale files; parity test passes        |
| A11Y-01     | 07-03       | 사이드바 활성 항목에 aria-current="page"가 설정된다               | ✓ SATISFIED  | `sidebar-nav-item.tsx:24`; test in `sidebar-nav-item.test.tsx` passes |
| A11Y-02     | 07-03       | 메인 콘텐츠로 건너뛰는 skip link가 있다                           | ✓ SATISFIED  | `layout.tsx:17`; layout test asserts `href="#main-content"`        |
| A11Y-03     | 07-03       | nav, aside, main에 의미 있는 aria-label이 있다                    | ✓ SATISFIED  | All 3 landmarks have aria-labels via `a11y.*` i18n keys            |
| A11Y-04     | 07-03       | 검색 입력에 명시적 label이 있다                                   | ✓ SATISFIED  | `filter-bar.tsx:72-76`; `filter-bar.test.tsx` passes               |

**Note:** The traceability table in `REQUIREMENTS.md` shows "Not started" for all Phase 7 requirements, but this is stale — the `[x]` checkboxes in the requirements list confirm they are marked complete, and the code confirms full implementation.

---

### Anti-Patterns Found

| File                                       | Line | Pattern              | Severity | Impact                                                                 |
|--------------------------------------------|------|----------------------|----------|------------------------------------------------------------------------|
| `content-table.tsx`                        | 83   | `eslint-disable-next-line react-hooks/set-state-in-effect` | ℹ️ Info | Pre-existing issue from commit da60f8d; intentional with documented reason; not introduced by Phase 7 |

No blockers or warnings. The eslint-disable is pre-existing, intentional, and documented.

---

### Human Verification Required

#### 1. Locale Switching Visual Verification

**Test:** Open admin in browser, switch locale via the locale switcher (ko → ja → en). Inspect table headers, filter labels, toast messages, and the cancel button in reject dialogs.
**Expected:** All text switches to the selected language with no hardcoded Japanese/Korean visible in Japanese or English mode.
**Why human:** next-intl server/client rendering requires a running app; locale switching behavior cannot be verified statically.

#### 2. Skip Link Keyboard Navigation

**Test:** Open admin in a browser, tab to the page from the address bar. The first Tab keypress should reveal a visible "메인 콘텐츠로 건너뛰기" / "Skip to main content" link at the top-left. Pressing Enter should scroll focus to the main content area.
**Expected:** Skip link appears on first Tab, disappears when focus moves away, and jumps keyboard focus to `#main-content`.
**Why human:** Focus visibility and scroll behavior require a running browser; CSS `focus:not-sr-only` rendering cannot be verified statically.

#### 3. Screen Reader Landmark Announcement

**Test:** Use VoiceOver (macOS) or NVDA (Windows) to navigate the admin sidebar. Navigate by landmarks (Rotor on VoiceOver: VO+U).
**Expected:** Landmarks announced as "sidebar" (aside), "Primary navigation" (nav), and "Main content" (main) in the current locale.
**Why human:** Actual screen reader behavior depends on AT + browser combination; cannot be verified without assistive technology.

---

### Gaps Summary

No gaps. All 8 observable truths verified, all artifacts exist and are substantively implemented, all key links are wired, and all 5 behavioral spot-check test suites pass. Three items are routed to human verification for browser/AT-dependent behavior but pose no code gaps.

---

_Verified: 2026-04-01T09:15:00Z_
_Verifier: Claude (gsd-verifier)_
