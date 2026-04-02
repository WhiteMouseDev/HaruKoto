# Phase 8: i18n Gap Closure — TTS Hook Toast - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 08-i18n-gap-closure-tts-hook-toast
**Areas discussed:** i18n 전환 방식, 테스트 범위 확장, 에러 메시지 fallback

---

## i18n 전환 방식

| Option | Description | Selected |
|--------|-------------|----------|
| 훅 내부 useTranslations | 훅 내부에서 useTranslations('tts')를 호출하고 toast.success(t('regenerate.success'))로 전환. 단순하고 기존 패턴과 일치. | ✓ |
| 콜백 파라미터 주입 | 훅에 onSuccess/onError 콜백을 추가하고, 컴포넌트에서 번역된 문자열을 전달. 훅이 i18n에 비의존적이 되지만 복잡도 증가. | |

**User's choice:** 훅 내부 useTranslations (Recommended)
**Notes:** None

---

## 테스트 범위 확장

| Option | Description | Selected |
|--------|-------------|----------|
| 최소 allowlist | .ts 확장 후 실패하는 파일만 allowlist에 추가. locale-switcher.tsx 외에 정당한 이유로 CJK가 필요한 파일만 허용. | ✓ |
| 디렉토리 기반 제외 | __tests__/, node_modules/ 외에 lib/api/ 등 서버 통신 파일도 제외. 서버 응답의 CJK는 하드코딩이 아님. | |

**User's choice:** 최소 allowlist (Recommended)
**Notes:** None

---

## 에러 메시지 fallback

| Option | Description | Selected |
|--------|-------------|----------|
| i18n fallback 우선 | 항상 i18n 메시지 사용: toast.error(t('regenerate.error')). 서버 에러 메시지는 무시. 사용자에게 일관된 로케일 경험. | ✓ |
| 서버 메시지 + i18n fallback | err.message가 있으면 서버 메시지 표시, 없으면 i18n fallback. 서버의 상세 에러 정보를 보여줄 수 있음. | |

**User's choice:** i18n fallback 우선 (Recommended)
**Notes:** None

---

## Claude's Discretion

- i18n 키 네이밍 세부 구조 (regenerate.success vs tts.regenerateSuccess 등)
- 테스트 함수명 리팩토링 (findTsxFiles → findSourceFiles 등)

## Deferred Ideas

None
