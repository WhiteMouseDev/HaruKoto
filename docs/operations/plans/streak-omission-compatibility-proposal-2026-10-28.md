# 연속 학습일·달력 누락 수정의 호환 범위

작성일: 2026-10-28 KST. 노선도 누락 감사에서 원본에 남은 연속 학습일 날짜 경계 수정과 학습 이력 필드가 최신 main에 없음을 확인했다. 아래 두 범위는 분리한다. 이 문서는 API·DB 변경을 자동 승인하는 문서가 아니다.

## 기존 계약을 유지하는 KST 날짜 계산 수정

서버의 현행 `update_streak`는 UTC timestamp의 날짜 부분과 한국 날짜를 비교하는 경로가 있다. 날짜만 있는 값과 timezone-aware/legacy-naive datetime을 KST 날짜로 정규화하고 같은 날·역행 시 중복 증가를 막는 원본 순수 함수를 선별한다. 과거 잘못 계산된 카운터·복습 기한·이벤트를 일괄 보정하거나 읽기 시 재계산하지 않는다. 이후 정상 학습 완료 시의 기존 streak 갱신을 올바른 날짜로 계산한다.

웹은 별도 Prisma/BFF와 날짜 계산 경로가 있어 서버 수정만으로 웹까지 고쳐졌다고 말하지 않는다. 웹의 순수 날짜·streak 계산도 같은 경계 표본으로 별도 검토한다. 새 API·DB·환경 계약·정책 버전 변경이나 새 잠금/영속 출석 마커는 포함하지 않는다.

## 사용자 승인된 API 추가안

- 메서드·경로: 인증된 `GET /api/v1/stats/history`.
- query: 기존 선택형 `year`, `month` 정수 그대로.
- 성공 status·외형: `200 HistoryResponse { year, month, records[] }` 그대로.
- 새 응답: `records[].hasStudied: boolean`. 서버는 각 기존 record에 non-null bool을 반환한다.
- 기존 record의 date·wordsStudied·quizzesCompleted·correctAnswers·totalAnswers·conversationCount·studyTimeSeconds·xpEarned는 유지한다.
- 계산: 현재 대시보드와 같은 일별 집계의 학습 활동 predicate를 사용한다. 학습 단어·퀴즈·회화·XP·가나·문법·문장·학습 시간 중 하나라도 양수이면 true다. 기존 DB 행을 변경하거나 새 출석 사실을 저장하지 않는다.
- 의미: **기존 집계에서 확인되는 활동 여부**다. 아직 완료하지 않은 로컬 카드 학습이나 과거 집계에 남지 않은 활동까지 보증하는 영속 출석 증거가 아니다.
- DB·마이그레이션·과거 기록 backfill·복습 기한·정답·XP 변경은 없다. 별도의 영속 마커 제안은 미승인으로 남긴다.
- 모바일: optional bool로 읽고 필드가 없는 구 서버에서는 기존 계산으로 fallback한다. 서버·앱 동시 배포를 강제하지 않는다.
- 웹: 현재 별도 Prisma/BFF와 HistoryRecord를 사용해 이 FastAPI DTO를 직접 소비하지 않는다. 필드 추가가 웹 달력 의미까지 바꾼다고 주장하지 않는다.
- OpenAPI·공유 TS는 최신 main에서 생성한다. 원본 생성 타입을 복사해 현재 오답 복습 API를 지우지 않는다.

2026-10-30 사용자 응답 **“API 필드 추가까지 복구”**로 이 범위가 승인됐다. backend가 계약·스냅샷을 발행하고 최신 공유 타입을 생성한 뒤 모바일이 소비한다. 구 응답·새 응답·명시적 false·집계 0과 날짜 경계 회귀를 검증한다. 서버·공유 타입은 PR #202, 모바일은 PR #201에서 검토하며 실제 운영 배포·기기 설치는 소스 구현과 별도 단계다.
