# Phase 3: Content Editing & Review Workflow - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.

**Date:** 2026-03-26
**Phase:** 03-content-editing-review-workflow
**Areas discussed:** 편집 폼 레이아웃, 승인/반려 워크플로우, 감사 로그 & 이력, 데이터 수정 API

---

## 편집 폼 레이아웃

| Option | Description | Selected |
|--------|-------------|----------|
| 전용 페이지 | /vocabulary/[id] 같은 상세 페이지에서 직접 편집 | ✓ |
| 모달/슬라이드오버 | 목록에서 항목 클릭 시 사이드 패널 또는 모달로 편집 | |

**User's choice:** 전용 페이지

| Option | Description | Selected |
|--------|-------------|----------|
| 페이지 유지 + 성공 토스트 | 저장 후 같은 편집 페이지에 머물며 성공 토스트 표시 | ✓ |
| 목록으로 돌아가기 | 저장 후 해당 콘텐츠 목록 페이지로 리다이렉트 | |

**User's choice:** 페이지 유지 + 성공 토스트

---

## 승인/반려 워크플로우

| Option | Description | Selected |
|--------|-------------|----------|
| 편집 페이지 상단 | 편집 폼 위에 승인/반려 버튼 배치 | ✓ |
| 편집 페이지 하단 | 편집 폼 아래에 승인/반려 영역 | |

**User's choice:** 편집 페이지 상단

| Option | Description | Selected |
|--------|-------------|----------|
| 모달 다이얼로그 | 반려 버튼 클릭 시 모달에서 사유 입력 | ✓ |
| 인라인 텍스트 | 편집 페이지에 사유 입력 필드 직접 표시 | |

**User's choice:** 모달 다이얼로그

| Option | Description | Selected |
|--------|-------------|----------|
| 목록 체크박스 + 상단 툴바 | 체크박스 선택 시 상단에 일괄 처리 툴바 표시 | ✓ |
| 드롭다운 메뉴 | 체크박스 선택 후 드롭다운으로 액션 선택 | |

**User's choice:** 목록 체크박스 + 상단 툴바

---

## 감사 로그 & 이력

| Option | Description | Selected |
|--------|-------------|----------|
| 타임라인 | 시간순 타임라인으로 이력 표시 | ✓ |
| 테이블 | 행/열 테이블로 이력 표시 | |

**User's choice:** 타임라인

| Option | Description | Selected |
|--------|-------------|----------|
| 편집 페이지 하단 | 편집 폼 아래에 감사 로그 섹션 | ✓ |
| 별도 탭/섹션 | 편집 폼과 감사 로그를 탭으로 분리 | |

**User's choice:** 편집 페이지 하단

---

## 데이터 수정 API

| Option | Description | Selected |
|--------|-------------|----------|
| PATCH | 변경된 필드만 전송 | ✓ |
| PUT (전체 교체) | 전체 객체를 전송하여 교체 | |

**User's choice:** PATCH

| Option | Description | Selected |
|--------|-------------|----------|
| Submit 시에만 | Phase 1 D-03 유지 — 저장 버튼 클릭 시에만 검증 | ✓ |
| 실시간 검증 | 필드 이탈 시 바로 검증 | |

**User's choice:** Submit 시에만

---

## Claude's Discretion

- 편집 폼 필드 레이아웃, React Hook Form + Zod 설계
- audit_logs 테이블 인덱스, 타임라인 컴포넌트, 일괄 API 설계
- 편집 페이지 로딩 스켈레톤

## Deferred Ideas

None
