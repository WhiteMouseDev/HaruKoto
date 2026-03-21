# 모바일-백엔드 API 불일치 분석 결과

> 분석일: 2026-03-12
> 상태: 분석 완료 / 수정 대기 (백엔드 검증 후 진행)

## 개요

Flutter 모바일 앱과 FastAPI 백엔드 간 API 불일치를 전수 분석한 결과입니다.
**총 26건** 발견 (CRITICAL 15 / HIGH 7 / MEDIUM·LOW 4)

> **주의**: 백엔드 자체의 정확성을 웹(Next.js) API 기준으로 별도 검증 필요.
> 웹은 정상 작동 중이므로 웹 API를 정답 기준으로 삼아 FastAPI를 검증한 후 수정 진행.

---

## CRITICAL — 앱 기능 완전 실패 (15건)

### Study/Quiz 영역 (4건)

#### 1. `/quiz/resume` - HTTP 메서드 불일치
- **모바일**: `POST /quiz/resume` with `{sessionId}` in body
- **백엔드**: `GET /quiz/resume` (body 없음)
- **영향**: 퀴즈 이어하기 기능 실패

#### 2. `/study/wrong-answers` - 응답 구조 완전 불일치
- **모바일 기대**: `{entries[], total, totalPages, summary}`
- **백엔드 응답**: `{wrongAnswers[]}` (entries/summary 없음)
- **영향**: 오답 노트 페이지 크래시

#### 3. `/study/learned-words` - 응답 필드명/구조 불일치
- **모바일 기대**: `{entries[], total, totalPages, summary}`
- **백엔드 응답**: `{words[], total, page, pageSize}` (totalPages/summary 없음)
- **영향**: 학습 단어 페이지 크래시

#### 4. `/quiz/wrong-answers` - 필드 누락
- **모바일 기대**: `exampleSentence`, `exampleTranslation`
- **백엔드 응답**: 해당 필드 없음
- **영향**: 오답 상세에서 예문 미표시

### Chat/Conversation 영역 (6건)

#### 5. Chat History - `type` 필드 부재
- **모바일 기대**: 대화 타입 (VOICE/TEXT) 구분
- **백엔드 응답**: `type` 필드 미포함
- **영향**: 대화 타입 정보 손실

#### 6. Get Conversation - `scenario` 필드 부재
- **모바일 기대**: 대화 시나리오 정보
- **백엔드 응답**: `scenario` 필드 미포함
- **영향**: 시나리오 정보 표시 불가

#### 7. End Chat - `xpEarned`/`events` 미파싱
- **모바일 기대**: 대화 종료 시 XP, 업적 이벤트
- **백엔드 응답**: 해당 필드 미포함 또는 구조 불일치
- **영향**: 게임화 시스템 완전 실패

#### 8. Get Characters - 응답 구조 오류
- **모바일 기대**: 특정 구조의 캐릭터 리스트
- **백엔드 응답**: 다른 구조
- **영향**: 캐릭터 목록 빈 화면

#### 9. Character Stats - 필드명 불일치
- **모바일 기대**: `characterStats`
- **백엔드 응답**: `stats`
- **영향**: 캐릭터 통계 미표시

#### 10. Character Favorites - 필드명 불일치
- **모바일 기대**: `favoriteIds`
- **백엔드 응답**: `favorites`
- **영향**: 즐겨찾기 로드 실패

### Stats 영역 (2건)

#### 11. Stats History - 쿼리 + 응답 완전 불일치
- **모바일**: `?year=2026&month=3` + 응답 `{records[]}` (8개 필드)
- **백엔드**: `?days=30` + 응답 `{days[]}` (4개 필드)
- **영향**: Stats 페이지 데이터 표시 안 됨

#### 12. Dashboard/Profile - 구조 불일치
- **모바일 기대**: kanaProgress, levelProgress 등
- **백엔드 응답**: 구조 차이
- **영향**: 대시보드 일부 데이터 누락

### My/Profile 영역 (3건)

#### 13. Profile Detail - 응답 구조 완전 불일치
- **모바일 기대**: `{profile, summary, achievements}`
- **백엔드 응답**: `{profile, stats}`
- **영향**: 프로필 통계/업적 미표시

#### 14. Subscription Status - 필드명 불일치
- **모바일 기대**: `chatLimit`, `callLimit`
- **백엔드 응답**: `chatSeconds`, `callSeconds`
- **영향**: AI 제한량이 0으로 표시

#### 15. Payments - URL 경로 불일치
- **모바일**: `GET /subscription/payments`
- **백엔드**: `GET /payments/`
- **영향**: 404 Not Found → 결제 내역 조회 불가

---

## HIGH (7건)

| # | 영역 | 엔드포인트 | 문제 |
|---|------|-----------|------|
| 1 | My | `DELETE /user/account` | 엔드포인트 미구현 |
| 2 | My | `POST /subscription/subscribe` | 백엔드는 checkout→activate 2단계 |
| 3 | Chat | Live Feedback | `duration` vs `durationSeconds` |
| 4 | Chat | Live Feedback | `xpEarned`/`events` 미파싱 |
| 5 | Chat | Get Scenarios | `category` 필터 미구현 |
| 6 | Study | `POST /quiz/answer` | `isCorrect` 필드 무시 (백엔드가 자체 검증) |
| 7 | Study | `POST /wordbook` | 응답 처리 불일치 |

---

## MEDIUM/LOW (4건)

| # | 영역 | 문제 |
|---|------|------|
| 1 | My | Onboarding `showKana` 필드 미수용 |
| 2 | My | `notificationEnabled` 필드 부재 |
| 3 | My | `levelProgress` 필드 부재 |
| 4 | My | 결제 기능 모바일 구현 미완료 |

---

## 이미 수정된 항목 (이 분석 전 수정)

- [x] `/quiz/start` 응답 `id`→`questionId`, `question`→`questionText` 매핑 (quiz_question_model.dart)
- [x] `/quiz/start` `correctOptionId` 응답에 포함 (quiz.py)
- [x] `/quiz/incomplete` 엔드포인트 추가 (quiz.py)
- [x] `/quiz/stats` 레벨별 콘텐츠 통계 지원 추가 (quiz.py)

---

## 다음 단계

1. **웹(Next.js) API ↔ FastAPI 백엔드 일치 검증** ← 현재 진행
   - 웹이 정상 작동하므로 웹 API를 정답 기준으로 삼음
   - FastAPI가 웹 API와 동일한 응답을 반환하는지 검증
2. 검증 결과를 바탕으로 백엔드 수정
3. 모바일 모델을 수정된 백엔드에 맞춤
