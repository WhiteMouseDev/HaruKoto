<!--
  PR 템플릿 — 빈 필드 금지. 해당 없으면 "N/A" 또는 "none" 명시.
  목적: AI 생성 PR도 사람이 쓴 것도 같은 구조로 리뷰 가능하게 한다.
-->

## Summary

<!-- 이 PR이 무엇을 바꾸는지 1~3 문장. 왜 하는지까지 포함. -->



## Risk

<!-- 아래 4단계 중 하나. 파일 경로 기반으로 판단하고, 애매하면 위로 올린다. -->
- [ ] **Low** — 오타, 주석, 테스트 추가, 문서
- [ ] **Medium** — 신규 컴포넌트, 기존 로직 수정, UI 조정
- [ ] **High** — API 계약 변경, 공유 타입 변경, 새 의존성, 환경 변수
- [ ] **Critical** — 결제, 인증, 권한, DB 마이그레이션, TTS 파이프라인, 보안

## Affected domains

<!-- 건드린 워크스페이스 전부. 하나라도 체크했으면 해당 AGENTS.md 읽고 검증 필요. -->
- [ ] `apps/web` (학습자 앱)
- [ ] `apps/admin` (리뷰어 어드민)
- [ ] `apps/landing` (마케팅)
- [ ] `apps/api` (FastAPI 백엔드)
- [ ] `apps/mobile` (Flutter)
- [ ] `packages/*` (공유 패키지 — 컨슈머 전부 검증 필요)
- [ ] `.github/workflows/**` (CI 자체 — 자기 반영성 유의)
- [ ] `docs/**` / `.planning/**` (문서/계획)

## AI provenance

<!-- AI가 생성했는지, 어떤 에이전트였는지 밝힌다. 리뷰어 주의 레벨이 다르다. -->
- [ ] 🤖 **AI 생성** — 어느 도구/에이전트: `<예: Claude Code web-agent, Codex review, 병행>`
- [ ] 👤 **사람 작성** (AI 지원 없이)
- [ ] 🧑‍🤝‍🧑 **사람 + AI 협업** — AI가 한 부분: `<구체적>`

AI 생성 PR일 경우 추가로:
- 사람이 직접 돌려본 범위: `<예: 로컬에서 admin 실행 + vocabulary 페이지 수동 QA>`
- AI 판단에서 의심스러웠던 부분: `<none 또는 구체적>`

## Verification run

<!-- 로컬에서 실제로 실행한 커맨드와 결과. "되겠지"는 금지. -->

```
# 예시 — 실제 실행한 것만 남기고 나머지는 지움
pnpm lint                                   # pass / fail: ...
pnpm typecheck                              # pass
pnpm test                                   # X passed / 0 failed
pnpm --filter @harukoto/admin e2e           # pass (admin browser smoke)
pnpm --filter @harukoto/admin build         # pass
cd apps/api && uv run pytest tests/ -v      # pass (N tests)
cd apps/mobile && flutter analyze           # 0 issues
cd apps/api && uv run python scripts/validate_mobile_contracts.py  # clean
```

## Downstream impact

<!--
  계약/공유 타입/스키마를 건드렸다면 어느 컨슈머가 영향받고, 어떻게 처리했는지.
  "영향 없음"이라면 그 판단 근거까지 적는다.
-->



## Rollback plan

<!--
  문제 시 어떻게 되돌리는가. 다음 중 하나를 명시.
  - git revert <SHA>만으로 충분 (무상태 변경)
  - DB 마이그레이션 downgrade: alembic downgrade -1
  - Feature flag off (flag 이름 명시)
  - 재배포 후 수동 데이터 보정 필요 (구체 절차)
-->



## Linked docs / issues

<!-- ADR, PRD, GSD 플랜, 에스컬레이션, 이전 PR 링크. 있으면. -->

- Phase plan: `.planning/phases/...`
- Escalation: `.planning/escalations/...`
- Spec: `docs/...`
