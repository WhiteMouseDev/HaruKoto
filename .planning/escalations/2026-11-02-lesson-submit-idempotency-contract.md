---
raised_by: codex-root
raised_at: 2026-11-02
phase: lesson-submit-idempotency
severity: warn
status: resolved
resolved_at: 2026-11-02
---

## Resolution

사용자가 2026년 11월 2일 PR #211 병합과 제안된 API·DB 안의 구현, 회귀·시뮬레이터 검증을 명시적으로 승인했다. PR #211은 `2d78c1de`로 병합했다. 신규 제출/조회·빈 완료 영수증 테이블·원자적 처리·모바일 복구를 구현하고 격리 로컬 DB에서 검증한다. 운영 배포·운영 마이그레이션 실행은 이번 구현 단계와 분리하며, 기존 학습 기록·기한·로그인·음원 캐시·Data API 차단은 유지한다.

## What happened

레슨 제출은 현재 요청 식별·결과 재사용 없이 SRS·이벤트·시도 횟수를 처리한다. 모바일 pending 보호는 있지만 응답 유실 시 서버의 같은 제출 성공을 증명하거나 재전송을 한 번만 반영하지 못한다. 기존 body에 optional ID만 넣으면 구서버가 이를 무시할 수 있다.

## Decision required

사용자는 2026년 11월 2일 구체안 준비만 승인했고 실제 API·DB 변경은 적용 전에 확인하도록 요청했다. [API·DB 설계안](../../docs/operations/plans/lesson-submit-idempotency-proposal-2026-11-02.md)의 신규 제출/조회 경로·필수 submission/원래 계정 ID·완료 영수증 테이블·원자적 처리·모바일 단일 pending envelope·보존/배포/회귀 범위를 구현할지 승인 대기한다.

## Options considered

1. 새 경로·완료 영수증과 동일 계정/ID 원래 결과 재사용을 구현한다. 기존 submit과 ID 없는 pending은 소급 보장하지 않는다. 권장안이다.
2. 기존 submit에 optional ID만 추가한다. 구서버가 무시할 수 있어 안전한 신규 프로토콜로 권하지 않는다.
3. 요청 내용·완료 시각·기존 attempts로 중복을 추정한다. 의도적 재학습·다른 기기 제출과 혼동하므로 채택하지 않는다.
4. SRS 정책 통합이나 한 레슨 내 반복 항목 갱신 횟수까지 바꾼다. 현재 요청과 분리해 별도 정책 승인 대상이다.

## Recommended direction

새 테이블·권한·원자성·기존 기록 보존을 격리 PostgreSQL로 증명하고 서버를 먼저 준비한 뒤 새 앱의 새 제출만 전환한다. 401 계정 전환·구서버 fallback·콘텐츠 삭제/음원 변경·앱 재실행·이전 reader를 함께 검증한다. 과거 pending에 새 ID를 소급 부여하지 않는다.

## Side effects

승인 후 API router/schema/service·Alembic·SQLAlchemy·Prisma 미러·OpenAPI 생성 타입·모바일 저장/복구와 도메인 오류에 영향이 있다. 기존 학습 행·기한·캐시 백필/재계산·권한/환경/스케줄/Data API 변경은 제외한다. 현재 이 파일과 설계 문서만 작성했으며 실제 적용은 0이다.
