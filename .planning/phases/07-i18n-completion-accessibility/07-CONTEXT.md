# Phase 7: i18n Completion & Accessibility - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

UI의 모든 텍스트가 선택된 언어로 표시되고, 스크린 리더와 키보드 사용자가 어드민을 탐색할 수 있다.
하드코딩된 일본어/한국어 문자열을 i18n 키로 전환하고, 기본 접근성 요소(aria-current, skip link, landmark, 검색 label)를 추가한다.

</domain>

<decisions>
## Implementation Decisions

### 하드코딩 문자열 처리

- **D-01:** 카테고리 라벨(TRAVEL→旅行 등)은 messages/{locale}.json에 매핑하고 프론트에서 `t(`category.${value}`)` 로 변환한다 (서버 API 수정 불필요)
- **D-02:** audit-timeline 시간 표현(たった今, N分前 등)은 next-intl ICU MessageFormat 패턴으로 전환한다
- **D-03:** Zod 에러 메시지, toast 메시지, 에러 표시 등 모든 사용자 노출 문자열을 i18n 키로 전환한다 (console.log 등 개발자용 제외)
- **D-04:** 폼 라벨(単語, 読み方, 例文 등), placeholder('[\"選択肢1\"]' 등) 모두 i18n 전환한다
- **D-05:** i18n 네임스페이스는 기존 패턴(nav, auth, table, page, empty, error, review, tts) 유지하며 새 키를 추가한다 (category, validation, time, form 등)

### 접근성 구현

- **D-06:** 요구사항 4가지(A11Y-01~04)만 구현한다. 추가 접근성 작업은 별도 phase.
- **D-07:** skip link는 sr-only 스타일로 숨기고 Tab 포커스 시에만 표시하는 표준 패턴 사용
- **D-08:** skip link 대상은 main 콘텐츠 영역 (`id="main-content"`)
- **D-09:** aria-label도 locale에 맞게 i18n 키로 전환한다 (기존 하드코딩 일본어 aria-label 포함)

### 번역 검증

- **D-10:** src/ 내 .tsx 파일에서 일본어/한국어 문자 패턴을 grep으로 검사하는 CI 스크립트 추가 (locale-switcher 등 예외 파일 allowlist 관리)
- **D-11:** ko.json, ja.json, en.json 3개 메시지 파일의 키 집합 일치 검사 스크립트/테스트 추가

### Claude's Discretion

- 번역 검증 스크립트의 구체적 구현 방식 (shell script vs vitest)
- i18n 키 네이밍 세부 규칙
- 접근성 구현의 기술적 세부사항 (컴포넌트 구조 등)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### i18n Infrastructure
- `apps/admin/messages/ko.json` — 한국어 번역 메시지 (177줄, 기존 키 구조 참고)
- `apps/admin/messages/ja.json` — 일본어 번역 메시지
- `apps/admin/messages/en.json` — 영어 번역 메시지

### Hardcoded Strings (전환 대상)
- `apps/admin/src/app/(admin)/conversation/page.tsx` — 카테고리 라벨, 테이블 헤더 하드코딩
- `apps/admin/src/app/(admin)/conversation/[id]/page.tsx` — Zod 에러, toast, 에러 표시
- `apps/admin/src/app/(admin)/grammar/page.tsx` — 테이블 헤더 하드코딩
- `apps/admin/src/app/(admin)/grammar/[id]/page.tsx` — Zod 에러, toast, placeholder
- `apps/admin/src/app/(admin)/vocabulary/page.tsx` — 테이블 헤더 하드코딩
- `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` — toast, 에러 표시
- `apps/admin/src/app/(admin)/quiz/[id]/page.tsx` — Zod 에러, toast, placeholder
- `apps/admin/src/components/content/audit-timeline.tsx` — 시간 표현 하드코딩
- `apps/admin/src/components/content/content-table.tsx` — aria-label 하드코딩
- `apps/admin/src/components/content/reject-reason-dialog.tsx` — キャンセル 하드코딩

### Accessibility (구현 대상)
- `apps/admin/src/components/layout/sidebar.tsx` — aria-current 추가 대상
- `apps/admin/src/app/(admin)/layout.tsx` — skip link, landmark 추가 대상
- `apps/admin/src/components/content/filter-bar.tsx` — 검색 label 추가 대상

### i18n Infrastructure
- `apps/admin/src/components/layout/locale-switcher.tsx` — locale 전환 로직 (grep 예외 대상)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **next-intl**: 이미 설치/구성됨. `useTranslations()` 훅과 `getTranslations()` 서버 함수 사용 중
- **messages/{ko,ja,en}.json**: 177줄씩 3개 파일, 기존 네임스페이스 구조 확립
- **LocaleSwitcher**: 사이드바+헤더에 이미 존재, `/api/locale` 엔드포인트로 cookie 설정
- **shadcn/ui 컴포넌트**: 기본 aria 속성 일부 포함 (select, checkbox, dialog 등)
- **sr-only 클래스**: Tailwind CSS 4에 내장, skip link 구현에 바로 사용 가능

### Established Patterns
- `useTranslations('namespace')` 훅으로 클라이언트 컴포넌트에서 번역
- `getTranslations('namespace')` 서버 함수로 서버 컴포넌트에서 번역
- 네임스페이스별 분리: nav, auth, table, page, empty, error, review, tts

### Integration Points
- `apps/admin/src/app/(admin)/layout.tsx` — skip link와 main landmark 추가 지점
- `apps/admin/src/components/layout/sidebar.tsx` — aria-current 추가 지점
- 각 페이지 파일의 테이블 정의 부분 — 헤더/라벨 i18n 전환 지점

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-i18n-completion-accessibility*
*Context gathered: 2026-03-31*
