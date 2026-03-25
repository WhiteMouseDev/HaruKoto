# 학습 플로우 & 시나리오 문서

> **Canonical Platform**: Mobile (Flutter)
> **문서 성격**: Living Document (지속 업데이트)
> **설계 원본**: `docs/domain/learning/` (Frozen)

---

## 문서 목록

| 문서 | 설명 |
|------|------|
| [lesson-flow.md](lesson-flow.md) | 레슨 학습 플로우 (6단계 진행) |
| [quiz-core-flow.md](quiz-core-flow.md) | 퀴즈 공통 라이프사이클 |
| [quiz-category-rules.md](quiz-category-rules.md) | 7개 카테고리별 규칙/차이 매트릭스 |
| [lesson-quiz-handoff.md](lesson-quiz-handoff.md) | Lesson → SRS → Quiz → Gamification 연결 |
| [edge-cases-recovery.md](edge-cases-recovery.md) | 중단/복구/네트워크 에러 처리 |
| [state-transitions.md](state-transitions.md) | SRS/레벨/진도 상태 전이 |

---

## 용어 정의

| 용어 | 설명 |
|------|------|
| **Lesson** | 새 콘텐츠 학습. 챕터 기반 순차 진행 (Context → Reading → Practice → Result) |
| **Quiz** | 복습/평가. SRS 기반 문제 풀이 (Start → Answer → Complete → SRS Update) |
| **Smart Quiz** | SRS 알고리즘이 자동 선별한 복습 퀴즈 (due cards + new cards 혼합) |
| **SRS** | Spaced Repetition System. 간격 반복 학습 (SM-2 기반) |
| **Stage** | 학습 스테이지. 카테고리×레벨별 순차 진행 단위 |
| **GameEvent** | 게이미피케이션 이벤트 (업적, 레벨업, 스트릭 등) |

## Source of Truth 관계

```
docs/domain/learning/ (Frozen)     ← 설계 원본 (변경 X)
    ↓ 구현 기준
docs/flows/ (Living)               ← 실제 구현 상태 반영 (이 문서들)
    ↓ 코드 기준
apps/mobile/ + apps/api/           ← 코드가 최종 권위
```

## 플랫폼 표기 규칙

- 본문: Mobile 기준으로 작성
- Web 차이: 각 섹션 끝에 `> **Web MVP Delta**` 블록으로 표기
