# 엣지 케이스 & 복구 플로우

> **Canonical**: Mobile

---

## 1. 퀴즈 중단/복구

### 시나리오: 퀴즈 도중 앱 종료

```mermaid
sequenceDiagram
    participant User as 사용자
    participant App as 모바일 앱
    participant API as FastAPI

    Note over User,App: 퀴즈 진행 중 (5/10 문제)
    User->>App: 앱 종료 (크래시/백그라운드)

    Note over API: 세션은 DB에 유지<br/>답변은 fire-and-forget로 이미 저장

    User->>App: 앱 재실행
    App->>API: GET /quiz/incomplete
    API-->>App: { session: { id, answeredCount: 5, totalQuestions: 10 } }

    App->>User: "진행 중인 학습이 있어요" 배너
    User->>App: "계속하기" 탭
    App->>API: POST /quiz/resume { sessionId }
    API-->>App: { questions[], answeredQuestionIds: [5개] }

    Note over App: currentIndex = 5 (이미 답변한 문제 건너뜀)
    App->>User: 6번째 문제부터 재개
```

### 자동 정리 규칙
| 조건 | 처리 |
|------|------|
| 답변 0개 + 미완료 | 좀비 세션 → 자동 완료 처리 |
| 시작 후 24시간 경과 | 스테일 세션 → 자동 완료 처리 |
| 새 퀴즈 시작 시 미완료 존재 | 기존 세션 자동 완료 + XP 정산 |

### 멱등성 보장
```
POST /quiz/complete 재호출 시:
  session.completed_at이 이미 존재 → xp_earned: 0 반환 (중복 XP 방지)
```

---

## 2. 네트워크 에러

### 답변 전송 실패

```mermaid
flowchart TD
    A[사용자 답변 선택] --> B["POST /quiz/answer (fire-and-forget)"]
    B --> C{네트워크 성공?}
    C -->|Yes| D[서버에 저장]
    C -->|No| E[UI에 영향 없음]
    E --> F[다음 문제로 진행]
    F --> G[Resume 시 빈 답변은 건너뜀]
```

- `/quiz/answer`는 await 없이 전송 → **네트워크 실패가 UI를 블로킹하지 않음**
- 일부 답변이 누락될 수 있지만, 퀴즈 진행에는 영향 없음
- 완료 시 서버 기준 `correctCount`로 정산

### 퀴즈 완료 전송 실패

```mermaid
flowchart TD
    A["POST /quiz/complete"] --> B{성공?}
    B -->|Yes| C[결과 화면 표시]
    B -->|No| D[스낵바: 완료 처리 실패]
    D --> E[재시도 버튼 표시]
    E --> A
```

### 레슨 제출 실패
- `/lessons/{id}/submit` 실패 시 에러 표시
- 답안은 로컬에 보존 → 재시도 가능

---

## 3. 퀴즈 도중 뒤로가기

```mermaid
flowchart TD
    A[사용자가 뒤로가기] --> B[PopScope 다이얼로그]
    B --> C["퀴즈를 종료할까요?<br/>진행 상황은 저장돼요."]
    C -->|취소| D[퀴즈 계속]
    C -->|종료| E[퀴즈 페이지 Pop]
    E --> F[미완료 세션 유지]
    F --> G[다음 진입 시 이어하기 제안]
```

---

## 4. 레슨 도중 뒤로가기

| 현재 Step | 뒤로가기 동작 |
|-----------|-------------|
| Context Preview (Step 0) | 시스템 뒤로가기 허용 → 레슨 목록으로 |
| 나머지 Step (1~5) | `goBack()` → 이전 Step으로 |
| Result (Step 5) | "완료" 버튼만 → 레슨 목록으로 |

---

## 5. SRS 처리 실패

### 레슨 제출 시 SRS 격리

```mermaid
sequenceDiagram
    participant API as FastAPI
    participant SRS as SRS 엔진
    participant DB as Database

    API->>DB: BEGIN NESTED (Savepoint)
    API->>SRS: process_answer(item, isCorrect)

    alt SRS 성공
        SRS-->>API: 상태 업데이트 완료
        API->>DB: COMMIT Savepoint
    else SRS 실패
        SRS-->>API: 에러
        API->>DB: ROLLBACK Savepoint
        Note over API: 레슨 채점 결과는 유지<br/>SRS만 실패
    end

    API->>DB: COMMIT (레슨 완료)
```

- Savepoint 사용으로 **SRS 실패가 레슨 완료를 차단하지 않음**
- SRS 등록 실패 시: 레슨은 COMPLETED, SRS는 미등록 (다음 기회에 재등록)

---

## 6. 동시 세션

### 같은 유저가 여러 디바이스에서 퀴즈

| 시나리오 | 동작 |
|---------|------|
| 디바이스 A에서 퀴즈 시작 → 디바이스 B에서 새 퀴즈 시작 | A의 세션이 자동 완료됨 |
| 디바이스 A에서 퀴즈 진행 중 → B에서 /incomplete 호출 | A의 세션이 반환됨 |

- `/quiz/start` 호출 시 기존 미완료 세션이 자동 완료됨
- XP는 자동 완료된 세션의 정답 수 기준으로 정산

---

## 7. 데일리 미션 엣지 케이스

### 날짜 변경 (자정)

```mermaid
flowchart TD
    A["자정 이전: 퀴즈 시작"] --> B["자정 이후: 퀴즈 완료"]
    B --> C["DailyProgress는 완료 시점 날짜 기준"]
    C --> D["미션도 완료 시점 날짜 기준"]
    D --> E["이전 날짜 미션은 미완료로 남음"]
```

### 미션 생성 시점
- `GET /missions/today` 호출 시 해당 날짜 미션이 없으면 자동 생성
- 결정론적 알고리즘: `md5(date + userId)` → 같은 날 같은 유저 = 항상 같은 미션

---

## 8. 가나 퀴즈 특수 케이스

### 스테이지 퀴즈 vs 마스터 퀴즈

| 상황 | 동작 |
|------|------|
| 스테이지 퀴즈 통과 | 다음 스테이지 잠금해제 |
| 스테이지 퀴즈 미통과 | 같은 스테이지 재시도 가능 |
| 마스터 퀴즈 완료 | 업적 부여 (kana_hiragana_complete 등) |
| 이미 완료된 스테이지 재시도 | 점수 갱신, 잠금해제 변경 없음 |

---

> **Web MVP Delta**: Web에서는 미완료 세션 이어하기가 동일하게 동작. 레슨 관련 엣지 케이스는 해당 없음.
