# Phase 5: Reviewer Productivity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 05-reviewer-productivity
**Areas discussed:** 리뷰 큐 탐색 방식, 대시보드 진행률 표시, 새 데이터 알림

---

## 리뷰 큐 탐색 방식

| Option | Description | Selected |
|--------|-------------|----------|
| 목록 페이지에서 시작 | 리뷰 시작 버튼 → 첫 needs_review 항목으로 이동 | ✓ |
| 대시보드에서 시작 | 대시보드 수치 클릭 → 리뷰 큐 진입 | |
| 두 경로 모두 | 목록 + 대시보드 양쪽에서 진입 가능 | |

**User's choice:** 목록 페이지에서 시작

| Option | Description | Selected |
|--------|-------------|----------|
| 자동 이동 | 승인/반려 후 다음 needs_review 항목으로 자동 이동 | ✓ |
| 수동 이동 | 같은 페이지에 머무르고 직접 이동 | |

**User's choice:** 자동 이동

---

## 대시보드 진행률 표시

| Option | Description | Selected |
|--------|-------------|----------|
| 프로그레스 바 추가 | StatsCard에 approved/total 비율 프로그레스 바 + % 표시 | ✓ |
| 현재 충분 | 이미 수치가 보이므로 변경 불필요 | |
| Claude 판단에 맡김 | 적절히 개선 | |

**User's choice:** 프로그레스 바 추가

---

## 새 데이터 알림

| Option | Description | Selected |
|--------|-------------|----------|
| 헤더 뱃지 | 사이드바 메뉴 옆에 needs_review 수 뱃지 | ✓ |
| 대시보드 알림 섹션 | 대시보드에 최근 추가/변경 항목 리스트 | |
| 두 경로 모두 | 헤더 뱃지 + 대시보드 섹션 | |

**User's choice:** 헤더 뱃지

| Option | Description | Selected |
|--------|-------------|----------|
| needs_review 상태 항목 수 | 간단하게 상태 카운트, 추가 테이블 불필요 | ✓ |
| 최근 N일 내 추가/변경 | 시간 기반 필터링 | |
| 마지막 로그인 이후 추가 | 세션 기반 추적 필요 | |

**User's choice:** needs_review 상태 항목 수

---

## Claude's Discretion

- 리뷰 큐 정렬 순서, 네비게이션 디자인, 뱃지 폴링 주기

## Deferred Ideas

- 999.1: TTS 필드 UI 개선
- v2: 키보드 단축키, diff 뷰, 코멘트 기능
