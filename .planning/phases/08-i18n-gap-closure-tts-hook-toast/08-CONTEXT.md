# Phase 8: i18n Gap Closure — TTS Hook Toast - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

useTtsPlayer 훅의 하드코딩 일본어 toast 메시지를 i18n 키로 전환하고, hardcoded-strings 감지 테스트를 .ts 파일까지 확장한다.
Gap Closure: v1.1 마일스톤 감사에서 발견된 2개 i18n 누락 수정.

</domain>

<decisions>
## Implementation Decisions

### i18n 전환 방식
- **D-01:** useTtsPlayer 훅 내부에서 `useTranslations('tts')`를 직접 호출하여 toast 메시지를 번역한다
- **D-02:** `toast.success(t('regenerate.success'))` / `toast.error(t('regenerate.error'))` 패턴 사용
- **D-03:** 기존 `tts` 네임스페이스에 `regenerate.success`, `regenerate.error` 키를 추가한다

### 에러 메시지 전략
- **D-04:** 항상 i18n 메시지 우선 사용 — `toast.error(t('regenerate.error'))`. 서버 에러 메시지(err.message)는 무시하고 일관된 로케일 경험 제공

### 테스트 범위 확장
- **D-05:** `hardcoded-strings.test.ts`의 `findTsxFiles` 함수를 `.ts` + `.tsx` 모두 스캔하도록 확장
- **D-06:** allowlist는 최소 유지 — 현재 `locale-switcher.tsx`만. .ts 확장 후 실패하는 파일이 있으면 정당한 이유 확인 후에만 allowlist 추가
- **D-07:** `__tests__/`, `node_modules/` 디렉토리는 기존대로 제외

### Claude's Discretion
- i18n 키 네이밍 세부 구조 (regenerate.success vs tts.regenerateSuccess 등)
- 테스트 함수명 리팩토링 (findTsxFiles → findSourceFiles 등)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 수정 대상 파일
- `apps/admin/src/hooks/use-tts-player.ts` — 하드코딩 toast 메시지 2곳 (line 78, 81)
- `apps/admin/src/__tests__/hardcoded-strings.test.ts` — .tsx만 스캔, .ts 확장 필요

### i18n 메시지 파일
- `apps/admin/messages/ko.json` — 한국어 번역 (tts 네임스페이스에 키 추가)
- `apps/admin/messages/ja.json` — 일본어 번역
- `apps/admin/messages/en.json` — 영어 번역

### 참고 (Phase 7 패턴)
- `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` — Phase 7에서 toast i18n 전환 패턴 참고
- `.planning/phases/07-i18n-completion-accessibility/07-CONTEXT.md` — Phase 7 i18n 결정사항

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **useTranslations('tts')**: 이미 TtsPlayer 컴포넌트에서 사용 중, 훅에서도 동일하게 호출 가능
- **next-intl**: 프로젝트 전체에 설치/구성 완료, 'use client' 컴포넌트에서 useTranslations 사용 확립

### Established Patterns
- 훅 내부에서 useTranslations 호출 가능 (React 훅 규칙 준수)
- tts 네임스페이스에 기존 키: play, regenerate, confirm, noAudio 등
- Phase 7에서 확립한 패턴: Zod/toast/에러 메시지 모두 i18n 키로 전환

### Integration Points
- `use-tts-player.ts` onSuccess/onError 콜백 내부의 toast 호출 2곳만 수정
- 3개 locale 파일의 tts 섹션에 2개 키 추가

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

*Phase: 08-i18n-gap-closure-tts-hook-toast*
*Context gathered: 2026-04-02*
