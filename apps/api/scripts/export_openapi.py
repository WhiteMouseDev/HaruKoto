"""FastAPI OpenAPI spec 추출 스크립트.

DB 연결 없이 실행 가능. DATABASE_URL 환경변수만 있으면 됨 (더미 값 허용).

Usage:
    cd apps/api
    uv run python scripts/export_openapi.py
"""

import json
import os
from pathlib import Path

# DATABASE_URL이 없으면 더미 값 설정 (DB 연결 없이 spec만 추출)
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://dummy:dummy@localhost:5432/dummy",
)

from app.main import app  # noqa: E402

spec = app.openapi()
out = Path(__file__).resolve().parent.parent / "openapi" / "openapi.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Wrote {out} ({len(spec.get('paths', {}))} paths)")
