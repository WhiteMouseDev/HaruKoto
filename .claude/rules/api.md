---
paths:
  - "apps/api/**"
---

# API (Python/FastAPI) 규칙

## 코드 품질
- ruff로 lint + format 강제
- 커밋 전: `cd apps/api && uv run ruff check app/ tests/ && uv run ruff format --check app/ tests/`

## API 계약
- 입력/출력 스키마 명확히 정의
- 에러 응답 포맷 일관성 유지
- 응답 모델 변경 시 모바일 parser 키 호환성 확인 (3점 교차 검증)

## 보안
- 환경 변수는 Secret Manager 또는 `.env`에서 로드
- 사용자 입력 반드시 검증
- 인증/인가 미들웨어 적용
