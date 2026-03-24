# AGENTS.md

## Scope

Instructions in this file apply to `apps/api/**`.

## API Defaults

- Keep request and response schemas explicit with Pydantic models.
- Keep error response formats consistent across endpoints.
- Validate external input early and preserve auth and authorization checks.
- Prefer typed domain logic over ad hoc raw dictionaries when a schema already exists.
- API contract changes must consider web and mobile consumers before they ship.
- When changing response keys, enums, pagination, or auth semantics, assume mobile compatibility can break until proven otherwise.

## Validation

- `cd apps/api && uv run ruff check app/ tests/`
- `cd apps/api && uv run ruff format --check app/ tests/`
- `cd apps/api && uv run mypy app/`
- `cd apps/api && uv run pytest`

## Change Risk

- Changes to auth, push notifications, storage, AI integrations, or response schemas need explicit compatibility review.
