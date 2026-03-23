---
alwaysApply: true
---

# 개발 워크플로우 (Claude + Codex 협업)

## 역할 분담
- **Claude Code (주 개발자)**: 설계, 구현, 1차 검증 (lint/analyze/test)
- **Codex (시니어 리뷰어)**: 교차 검증, API 계약 검증, 반박
- **사용자 (PM)**: 최종 판단, 방향 결정

## 기능 개발 사이클 (6단계)
1. 설계 → Claude 초안 → Codex 검증 → 수렴
2. 구현 → Claude 코드 작성
3. 자체 검증 → lint/analyze/test 실행
4. 교차 검증 → Codex 코드 리뷰
5. 수렴 → Claude가 피드백 평가 → 수용/반박 → 사용자 보고
6. 커밋 → 합의된 코드만 커밋 & 푸시

## Codex 활용 규칙
- **설계 단계**: API 계약 변경, DB 스키마 변경, 외부 서비스 연동 시 Codex 검증 필수
- **교차 검증**: API 계약 정합성, 타입 안전성, 런타임 에러 가능성, 테스트 호환성

## 리뷰 규칙
- P0/P1 피드백: 반드시 수용 또는 근거 있는 반박
- P2 이하: Claude가 판단하여 수용/보류
- 반박 시 반드시 코드 라인 기준 근거 제시
- CamelModel, query parameter, raw dict 등 자동 변환 비적용 영역: 3점 교차 검증 필수
