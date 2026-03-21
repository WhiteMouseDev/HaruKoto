# ADR-001: MVP-β 스코프 동결

> 결정일: 2026-03-20
> 상태: **확정**
> 참여: Claude Code × Codex (3회 토론)

---

## 컨텍스트

Part 1 (30레슨) 파이프라인이 완성되어 SRS 엔진 구현에 진입.
04-DATA-SCHEMA.md에 미결 사항 2건이 있어 스코프 동결이 필요.

## 결정

### 1. synonym_groups 테이블 → **보류**

- MVP-β에서는 별도 테이블을 만들지 않음
- `vocabularies.synonym_group_id`, `grammars.synonym_group_id` nullable 컬럼만 추가
- 오답 안전장치(T08)는 `meaning_glosses_ko` 텍스트 기반 충돌 필터로 구현
- **이유**: 설계 원칙 "새 테이블 최소화" + 03-SRS-ENGINE.md가 1단계를 텍스트 필터로 정의

**나중 확장 경로**:
1. `synonym_groups(id, label, note)` 테이블 생성
2. 기존 `synonym_group_id` distinct 값으로 백필
3. FK 추가 → 관리 UI 구축

### 2. quiz_sessions 확장 → **보류**

- MVP-β에서는 `session_mode`, `source_lesson_id` 미도입
- 레슨 완료는 `user_lesson_progress`에만 기록 (quiz_sessions에 넣지 않음)
- `review_events`는 독립 로그 테이블로 운영 (`session_id`, `lesson_id` soft link)
- **이유**: quiz_sessions에 레슨을 섞으면 기존 통계/업적 지표 오염 + 스키마 변경 범위 증가

**나중 확장 경로**:
1. `quiz_sessions`에 `session_mode`, `source_lesson_id` nullable 추가
2. 기존 데이터 백필
3. 통계 쿼리에 `session_mode` 필터 반영

## MVP-β 전략

```
주축: SRS 코어 (상태머신 + review_events + 스마트 세션)
보조: UX 최소 신뢰선 (정답 피드백 + 복습 예약 표시)
콘텐츠: 기존 30레슨으로 베타, Part 2는 데이터 기반 확장
```

## 베타 출시 최소 기준

신규 유저가 Ch.01 레슨 1개 완료 후, 퀴즈 세션에서 SRS 상태 전이 + 피드백 + 복습 예약을 끊김 없이 경험.
