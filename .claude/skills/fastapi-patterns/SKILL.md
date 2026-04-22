---
name: fastapi-patterns
description: FastAPI/Python/SQLAlchemy/Alembic/Pydantic conventions for apps/api. Use when editing anything under apps/api — routers, services, models, schemas, or Alembic migrations.
---

# API (Python/FastAPI) Skill

`apps/api` 전용 FastAPI 백엔드 패턴.

## 코드 품질

- **ruff**로 lint + format 강제 (line-length 140, target py312)
- 커밋 전:
  ```bash
  cd apps/api && uv run ruff check app/ tests/
  cd apps/api && uv run ruff format --check app/ tests/
  cd apps/api && uv run mypy app/
  ```

## API 계약

- 입력/출력 스키마를 **Pydantic BaseModel**로 명확히 정의
- 에러 응답 포맷 일관성 유지 — `HTTPException(detail=...)` 패턴
- **응답 모델 변경 시 모바일 parser 키 호환성 확인** (3점 교차 검증 필수)
- 신규/변경 엔드포인트는 OpenAPI 스냅샷 재생성 필수:
  ```bash
  cd apps/api && uv run python scripts/export_openapi.py
  ```
  CI의 `api-contract` 잡이 freshness를 강제함.

## 구조 패턴

- **Routers** (`app/routers/`): HTTP 엔드포인트 정의, 비즈니스 로직 금지
- **Services** (`app/services/`): 도메인 로직
- **Models** (`app/models/`): SQLAlchemy ORM
- **Schemas** (`app/schemas/`): Pydantic I/O 스키마
- **async 일관성**: 라우터/서비스 모두 async

## 인증/보안

- 환경 변수는 Secret Manager 또는 `.env`에서 로드
- 사용자 입력 반드시 Pydantic으로 검증
- JWT 검증은 `app/dependencies.py:get_current_user` **재사용** (중복 구현 금지)
- Rate limit 필요 시 `app/middleware/rate_limit.py` 활용

## 에러 메시지 정책

- 사용자 노출 메시지: **한국어** (`"세션을 찾을 수 없습니다"`)
- 로그 메시지: 영어
- Pydantic 검증 실패는 자동으로 422 반환

## DB 변경 절차 (DDL authority)

1. `apps/api/alembic/versions/`에 마이그레이션 추가 (DDL 유일 권한)
2. `app/models/`와 `app/schemas/` 동시 업데이트
3. 왕복 테스트:
   ```bash
   uv run alembic upgrade head
   uv run alembic downgrade -1 && uv run alembic upgrade head
   ```
4. Prisma 동기화는 `shared-packages-agent`에게 위임 (직접 schema.prisma 편집 금지)

상세 DDL 거버넌스는 `api-plane-governance` skill 참고.

## 테스트

```bash
cd apps/api && uv run pytest tests/ -v --tb=short
```
