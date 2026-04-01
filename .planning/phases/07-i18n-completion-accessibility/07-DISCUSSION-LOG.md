# Phase 7: i18n Completion & Accessibility - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 07-i18n-completion-accessibility
**Areas discussed:** 하드코딩 문자열 처리 전략, 접근성 구현 범위, 번역 검증 방식

---

## 하드코딩 문자열 처리 전략

### 카테고리 라벨 처리
| Option | Description | Selected |
|--------|-------------|----------|
| 메시지 파일에 매핑 | messages/{locale}.json에 category.TRAVEL 등 추가, t(`category.${value}`)로 변환 | ✓ |
| 서버 API에서 번역된 라벨 제공 | API 응답에 locale 파라미터로 번역된 라벨 포함 | |
| 프론트 상수 맵 | category-labels.ts에 {TRAVEL: {ko, ja, en}} 매핑 | |

**User's choice:** 메시지 파일에 매핑 (Recommended)
**Notes:** 서버 부담 없이 기존 i18n 인프라 활용

### 시간 표현 처리
| Option | Description | Selected |
|--------|-------------|----------|
| i18n 메시지 + ICU 패턴 | next-intl ICU MessageFormat 활용 | ✓ |
| Intl.RelativeTimeFormat | 브라우저 네이티브 API | |

**User's choice:** i18n 메시지 + ICU 패턴 (Recommended)
**Notes:** 기존 i18n 인프라에 일관성 유지

### Validation/Toast 메시지
| Option | Description | Selected |
|--------|-------------|----------|
| 전부 i18n 전환 | 모든 사용자 노출 문자열을 i18n 키로 전환 | ✓ |
| 표시용만 i18n, 내부용 유지 | toast/alert만 전환, console.log 등은 그대로 | |

**User's choice:** 전부 i18n 전환 (Recommended)

### 네임스페이스 구조
| Option | Description | Selected |
|--------|-------------|----------|
| 기존 패턴 유지 + 확장 | 기존 네임스페이스에 새 키 추가 | ✓ |
| 페이지별 네임스페이스 분리 | 각 페이지마다 별도 네임스페이스 | |

**User's choice:** 기존 패턴 유지 + 확장 (Recommended)

### 폼 라벨
| Option | Description | Selected |
|--------|-------------|----------|
| 전부 i18n 전환 | 모든 폼 라벨, placeholder, 헬퍼 텍스트 전환 | ✓ |
| 필드명은 일본어 유지 | 학습 데이터 필드(単語, 読み方)는 일본어 유지 | |

**User's choice:** 전부 i18n 전환 (Recommended)

### Placeholder
| Option | Description | Selected |
|--------|-------------|----------|
| 전부 i18n 전환 | placeholder도 언어에 맞게 변환 | ✓ |
| 일본어 유지 | 학습 데이터 입력은 항상 일본어이므로 유지 | |

**User's choice:** 전부 i18n 전환 (Recommended)

---

## 접근성 구현 범위

### 구현 범위
| Option | Description | Selected |
|--------|-------------|----------|
| 요구사항 4가지만 | A11Y-01~04만 구현 | ✓ |
| 포커스 관리 추가 | 4가지 + 키보드 탐색 등 | |
| WCAG AA 수준 전체 감사 | 색상 대비, 포커스 인디케이터 등 전체 검토 | |

**User's choice:** 요구사항 4가지만 (Recommended)

### Skip link 동작
| Option | Description | Selected |
|--------|-------------|----------|
| 포커스 시만 표시 | sr-only로 숨기고 Tab 포커스 시 표시 | ✓ |
| 항상 표시 | 페이지 상단에 작은 링크로 항상 표시 | |

**User's choice:** 포커스 시만 표시 (Recommended)

### aria-label 언어
| Option | Description | Selected |
|--------|-------------|----------|
| i18n 전환 | locale에 맞게 번역 | ✓ |
| 영어로 통일 | 모든 aria-label을 영어로 | |

**User's choice:** i18n 전환 (Recommended)

### Skip link 대상
| Option | Description | Selected |
|--------|-------------|----------|
| main 콘텐츠 영역 | main 태그에 id="main-content" 추가 | ✓ |
| 첫 번째 인터랙티브 요소 | 페이지의 첫 버튼/입력/링크로 이동 | |

**User's choice:** main 콘텐츠 영역 (Recommended)

---

## 번역 검증 방식

### 검증 방법
| Option | Description | Selected |
|--------|-------------|----------|
| grep 기반 CI 검사 | .tsx에서 일본어/한국어 문자 패턴 grep, 예외 allowlist | ✓ |
| 테스트로 검증 | 각 locale로 렌더링하고 하드코딩 문자 확인 | |
| 수동 QA만 | 각 locale로 전환하며 육안 확인 | |

**User's choice:** grep 기반 CI 검사 (Recommended)

### 키 일치 검사
| Option | Description | Selected |
|--------|-------------|----------|
| 키 일치 검사 추가 | 3개 메시지 파일의 키 집합 동일 여부 검사 | ✓ |
| 검사 없음 | 수동 관리로 충분 | |

**User's choice:** 키 일치 검사 추가 (Recommended)

---

## Claude's Discretion

- 번역 검증 스크립트의 구체적 구현 방식 (shell script vs vitest)
- i18n 키 네이밍 세부 규칙
- 접근성 구현의 기술적 세부사항 (컴포넌트 구조 등)

## Deferred Ideas

None — discussion stayed within phase scope
