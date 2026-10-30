# HaruKoto Documentation

> 하루코토 프로젝트 문서 인덱스. 모든 문서의 단일 진입점입니다.

## 문서 구조

```
docs/
├── architecture/    # 시스템 아키텍처, API, DB, 인프라
├── domain/          # 도메인 지식 (학습, 게임화, 결제)
├── product/         # 기획, 화면, 로드맵, 디자인
├── decisions/       # ADR (Architecture Decision Records)
├── operations/      # 운영, 배포, 콘텐츠 파이프라인, QA
└── archive/         # 레거시/구식 문서 (참조용 보존)
```

## 핵심 문서 (빠른 접근)

### 제품

- [PRD (제품 요구사항)](product/prd.md)
- [화면 구조](product/screens/)

### 학습 시스템 (Part 1 완성)

- [학습 트랙 설계](domain/learning/learning-track.md) — 마이크로 레슨 10분 구조
- [퀴즈 트랙 설계](domain/learning/quiz-track.md) — 4탭 퀴즈 시스템
- [SRS 엔진](domain/learning/srs-engine.md) — 6단계 상태 머신, PROVISIONAL, FSRS
- [N5 커리큘럼 맵](domain/learning/n5-curriculum-map.md) — 90레슨 × 18챕터

### 아키텍처

- [학습 데이터 스키마](architecture/data/learning-data-schema.md) — 5개 테이블 + review_events
- [FastAPI 엔드포인트 맵](architecture/api/fastapi-endpoint-map.md)
- [인프라 구성](architecture/platform/infrastructure-overview.md)

### 의사결정

- [ADR-001: MVP-β 스코프](decisions/ADR-001-mvp-beta-scope.md) — synonym_groups/quiz_sessions 보류

### 운영

- [콘텐츠 파이프라인](operations/content/content-pipeline.md) — AI 생성 + PM 검수
- [홈 단어 카드의 오늘 목표 진행률](operations/plans/daily-vocabulary-goal-2026-10-30.md) — 하루 목표·퀴즈 이어하기·누적 숙련도 분리와 KST 고유 단어 집계
- [오늘 단어 목표의 실제 운영 반영](operations/plans/daily-vocabulary-goal-production-rollout-2026-10-30.md) — #204 배포·시뮬레이터 목표/추천/재실행 검증, 기존 기록·음원·보안 보존
- [N5 현재 음성·대표 청취 링크](operations/plans/n5-audio-qa-current-state-2026-10-28.md) — Kenzo·Shizuka v4 적용 범위, 전체 듣기와 별도 남은 전체 청취 검수
- [이어하기 카드와 최근 학습순](operations/plans/mobile-resume-recent-study-2026-10-28.md) — 대표 카드 한 개·전체 목록, 기존 저장 위치/답안 호환과 최근 활동 정렬
- [저장 목록을 짧게 만든 과정 (블로그)](blog/2026-10-28-one-resume-card-and-recent-study.md) — 중복 카드·학습 시각·실패 상태와 접근성 개선 기록
- [지하철 학습 UI가 사라진 원인과 복구 (블로그)](blog/2026-10-28-why-the-subway-ui-disappeared.md) — 미커밋 승인 디자인의 빌드 누락, 세 방향 소스 감사와 선택 복구
- [로컬 변경 누락 감사·복구 기록](operations/plans/mobile-local-changes-restoration-2026-10-28.md) — 446개 후보 분류, 모바일 회귀·KST 수정·별도 승인 항목과 롤백
- [학습 UI·연속일 실제 운영 반영](operations/plans/learning-ui-production-rollout-2026-10-30.md) — #202 서버 배포·#201 아이폰 업데이트, 기존 기록/캐시 보존과 실제 기기 확인 범위
- [레슨 Seed/TTS Rollout Runbook](operations/content/lesson-audio-qa-rollout-runbook.md) — N4 seed/TTS 운영 반영 preflight와 N3+ 확장 gate
- [콘텐츠 변환 가이드](operations/content/content-conversion-guide.md)
- [앱스토어 배포](operations/release/app-store-submission-guide.md)
- [v1.1 안정화 체크포인트](operations/release/v1.1-stabilization-checkpoint-2026-04-23.md) — 릴리스 경계, 자동 검증, 수동 UAT 게이트
- [**AI Coding Harness**](operations/harness.md) — Claude Code + Codex 운영체계 (도메인 에이전트, 스킬, 훅, 계약 관리, 에스컬레이션)
- [AI 하네스 엔지니어링 실전 구축기 (블로그)](blog/2026-04-23-ai-harness-engineering-실전-구축기.md) — 4-pillar 하네스 설계와 실제 드리프트 버그를 잡아낸 사례
- [학습 앱 개선 사례 기록](blog/2026-10-21-harukoto-improvement-casebook.md) — 학습 UI, 퀴즈 저장, 이어 풀기, DB 보안과 파티션 문제의 원인·설계·수정·검증
- [하루 목표 옆의 2%는 무엇을 뜻할까 (블로그)](blog/2026-10-30-daily-word-goal-and-quiz-progress.md) — 오늘 단어 목표와 퀴즈 진행·장기 숙련도를 분리한 이유와 검증
- [개선 기록 블로그 연재 구성](blog/2026-10-21-harukoto-blog-outline.md) — 주제별 글 구성과 공개 전 확인할 근거·진행 상태
- [읽기 전용 파티션 검사 구현 계획](operations/plans/read-only-partition-check-2026-10-21.md) — DB 구조 검사, 회귀 테스트와 별도 승인이 필요한 운영 배치안
- [파티션 정기 점검 운영 적용](operations/plans/partition-monitor-deployment-2026-10-21.md) — 최소 권한 계정, 오전 9시 예약, 실제 실행·누락·오류·복구 알림 검증과 중단 절차
- [파티션 자동 점검 감사·2월 보완 제안](operations/plans/partition-monitor-audit-2026-10-30.md) — 9일 연속 자연 실행 확인, 2027년 2월 부재와 승인 전 추가·보존 절차
- [2027년 2월 파티션 보완 적용 기록](operations/plans/review-event-february-partition-rollout-2026-10-30.md) — 승인된 단일 파티션 마이그레이션, 보존 회귀와 운영·시뮬레이터 검증 단계
- [특수 퀴즈 이어하기 계약 제안](operations/plans/special-quiz-resume-contract-proposal-2026-10-30.md) — matching/arrange 모드·표시 snapshot, 기존 세션 무백필 처리와 웹·모바일 회귀안
- [특수 퀴즈 이어하기 구현·검증](operations/plans/special-quiz-resume-implementation-2026-10-30.md) — 같은 세션·원본 ID 복원, 정답/오답 제외, 기존 복습 기한 보존과 격리 시뮬레이터 검증
- [특수 퀴즈 이어하기 운영 반영](operations/plans/special-quiz-resume-production-rollout-2026-10-30.md) — 웹 선행 배포·#209 병합·서버/앱 반영 순서와 기존 기록·복습 기한·음원·보안 보존 확인
- [레슨 문항과 복습 항목 연결 수정](operations/plans/lesson-review-target-fix-2026-10-21.md) — 명시 참조 계약, 회귀 테스트, 기존 기록 영향과 승인 전 운영 데이터 적용안
- [Codex 운영 가이드](operations/codex-workflows.md) — 프로필, 프롬프트 템플릿, 모노레포 검증 기준
- [Codex 스모크 테스트](operations/codex-smoke-test.md) — 첫 실전 테스트용 프롬프트 모음
- [모바일 아키텍처 감사 (2026-03-24)](operations/audits/mobile-architecture-audit-2026-03-24.md) — 모바일 구조 문제점과 개선 우선순위
- [모바일 시작/스플래시 정책 (2026-03-24)](operations/mobile/mobile-startup-splash-policy-2026-03-24.md) — 스플래시 길이와 시작 경험 기준
- [모바일 비스플래시 개선 설계 (2026-03-24)](operations/plans/mobile-non-splash-improvement-design-2026-03-24.md) — 네트워크, 설정, 세션, 테스트 개선 설계
- [모바일 비스플래시 실행 로드맵 (2026-03-24)](operations/plans/mobile-non-splash-implementation-roadmap-2026-03-24.md) — 단계별 작업 순서와 완료 기준

## 콘텐츠 데이터

레슨 콘텐츠 JSON은 `packages/database/data/lessons/n5/`에 위치합니다:

```
packages/database/data/lessons/n5/
├── ch01-greetings-and-first-meetings.json
├── ch02-introducing-things-and-people.json
├── ch03-location-and-movement.json
├── ch04-verb-basics.json
├── ch05-past-and-sequence.json
└── ch06-progress-and-habits.json
```

개발/스테이징 DB에 학습 콘텐츠를 재현할 때는 root에서 통합 시드 명령을 실행합니다.

```bash
DATABASE_URL="postgresql+asyncpg://user:pass@host:5432/db" pnpm seed:learning
```

## 문서 규칙

- **정본 원칙**: 코드가 문서보다 최신이면 문서를 업데이트
- **ADR/RFC**: 번호 체계 유지 (ADR-001, RFC-0001)
- **일반 문서**: 의미있는 파일명, 번호 불필요
- **아카이브**: 구식 문서는 삭제하지 않고 `archive/`로 이동
- **기능 계획 문서**: `docs/operations/plans/`에 유지
- **GSD 상태 문서**: `.planning/`에 유지
- **CLAUDE.md**: 작업 규칙/워크플로 전용, 도메인 지식은 `docs/`에
