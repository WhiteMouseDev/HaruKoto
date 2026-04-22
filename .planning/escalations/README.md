# Escalation Inbox

AI 에이전트가 **자체 판단 범위를 벗어난 결정**을 맞닥뜨렸을 때 이 디렉토리에
마크다운 파일을 남깁니다. 다음 세션 시작 시 자동으로 스캔되어 사용자에게 노출됩니다.

## 언제 에스컬레이션을 만드는가

자동화 연속성을 위해 다음 상황에서 **작업을 중단하지 말고** 에스컬레이션을 기록합니다:

1. **도메인 경계 위반이 필요함** — 예: mobile-agent가 실행 중인데 API 스키마 변경이 불가피한 경우
2. **계약(Contract) 변경 여부 판단 필요** — 예: Breaking change가 정당한지 PM 판단 필요
3. **보안 관련 결정** — 예: 새 환경변수 도입, 권한 모델 변경
4. **비용/성능 트레이드오프** — 예: 추가 API 호출 도입, 인덱스 추가 여부
5. **계획에 없는 요구사항 발견** — 예: 구현 중 PRD에 누락된 케이스 발견

## 파일 규약

- 파일명: `YYYY-MM-DD-short-slug.md` (예: `2026-04-22-mobile-offline-sync.md`)
- `resolved/` 서브디렉토리로 이동 = 해결됨
- 파일 포함 항목:

```markdown
---
raised_by: <agent-name or session>
raised_at: 2026-04-22T15:30:00+09:00
phase: <phase number if applicable>
severity: blocker | warn | info
status: open
---

## What happened
<1-2 문장으로 에이전트가 왜 멈췄는지>

## Decision required
<사용자가 내려야 하는 구체적 결정>

## Options considered
1. ...
2. ...

## Recommended direction
<에이전트가 판단한 우선안 + 근거>

## Side effects
<결정에 따라 영향받는 파일/시스템/다운스트림>
```

## 해결 워크플로우

1. 세션 시작 시 SessionStart 훅이 `status: open` 파일을 스캔해서 리스트업
2. 사용자가 결정 내림 → 해당 파일 상단에 `## Resolution` 섹션 추가
3. `status: resolved`로 변경
4. `resolved/YYYY-MM/`로 이동 (선택, 아카이브용)

## 원칙

- **작업을 완료하지 못한다고 세션을 끝내지 않습니다.** 기록하고 다른 할 수 있는 일을 계속합니다.
- **중복 에스컬레이션 금지.** 비슷한 결정은 기존 파일에 추가 옵션으로 병합합니다.
- **기한(`deadline` frontmatter)이 있으면 넣습니다.** 일부는 시간 민감.
