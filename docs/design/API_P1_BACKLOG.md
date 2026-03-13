# API P1 백로그 — 프로덕션 배포 전 수정 필요

> 작성일: 2026-03-14
> 근거: 백엔드 코드 감사 리포트 (P0 7건은 커밋 4e4fc91에서 수정 완료)
> 시점: Sprint 3~4 작업 중 해당 파일 수정 시 함께 처리, 또는 배포 전 일괄 처리

---

## API 설계

### 에러 응답 형식 통일
- **파일**: webhook.py, push.py 등
- **문제**: `{"detail": "..."}` vs `{"ok": True}` vs `{"success": True}` 혼재
- **수정**: `ErrorResponse` 스키마로 통일

### 엔드포인트 status_code 명시
- **파일**: auth.py 등 다수
- **문제**: `@router.post("/ensure-user")` → `status_code=200` 누락
- **수정**: 모든 엔드포인트에 명시적 status_code 추가

---

## 보안

### JWT 에러 핸들링 세분화
- **파일**: app/dependencies.py:91,133
- **문제**: `except Exception:` → 모든 JWT 에러 삼킴
- **수정**: `except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError)`

### 아바타 업로드 제한
- **파일**: app/routers/user.py:142-150
- **문제**: 파일 크기/횟수 제한 없음
- **수정**: MAX_FILE_SIZE 5MB + rate_limit 5회/시간

### kana.py dict 타입 → Pydantic 모델
- **파일**: app/routers/kana.py:148
- **문제**: `body: dict[str, Any]` → 입력 검증 우회
- **수정**: `KanaProgressRecord` Pydantic 모델 생성

---

## 성능

### stats.py N+1 쿼리
- **파일**: app/routers/stats.py:88-101
- **문제**: 단어 진도 통계 쿼리 3개+ 개별 실행
- **수정**: GROUP BY 집계 쿼리 1개로 통합

### kana.py 통계 쿼리 최적화
- **파일**: app/routers/kana.py:116-139
- **문제**: KanaType별 COUNT 쿼리 2개
- **수정**: 배치 쿼리로 통합

### DB 커넥션 풀 pool_recycle 설정
- **파일**: app/db/session.py
- **문제**: `pool_recycle` 미설정
- **수정**: `pool_recycle=3600` 추가

### 페이지네이션 COUNT 최적화
- **파일**: app/routers/study.py:50-51
- **문제**: 전체 데이터 COUNT 후 필터링
- **수정**: 커서 기반 페이지네이션 또는 인덱스 힌트

---

## 코드 품질

### Enum 값 추출 유틸 함수
- **파일**: study.py, kana.py, stats.py 등
- **문제**: `jlpt_level.value if hasattr(jlpt_level, "value") else jlpt_level` 반복
- **수정**: `utils/helpers.py`에 `enum_value()` 함수 생성

### DB refresh 패턴 불일치
- **파일**: auth.py vs missions.py
- **문제**: 커밋 후 refresh 여부가 일관적이지 않음

### 매직 넘버 상수화
- **파일**: kana.py:102 등
- **문제**: `stage.stage_number == 1` → 상수로 추출

### 구조적 로깅 추가
- **파일**: 대부분의 라우터
- **문제**: 최소한의 로깅만 존재
- **수정**: AI 엔드포인트 + 결제/구독 로직에 structured logging

---

## 테스트

### 누락 테스트 작성
- chat 라우터 (메인 AI 기능)
- subscription webhook
- payment 검증
- cron job

### conftest.py AsyncMock 개선
- **파일**: tests/conftest.py:52-54
- **문제**: AsyncMock이 쿼리 검증을 제대로 못함
- **수정**: 실제 테스트 DB 사용 또는 mock 강화

---

## 체크리스트

프로덕션 배포 전:
- [ ] 위 P1 항목 전부 처리
- [ ] `bandit` 보안 스캔 실행
- [ ] Alembic 마이그레이션 스테이징 DB에서 테스트
- [ ] CORS origins 실제 도메인으로 설정
- [ ] Sentry 에러 트래킹 활성화 확인
