# CI Watch

현재 브랜치의 최신 GitHub Actions 실행을 추적하고, 실패 원인을 요약합니다.

## 목표

- 최신 run의 성공/실패 상태 확인
- 실패 시 로그에서 직접적인 원인 추출
- 자동 수정 가능한 항목만 제한적으로 수정
- 자동 수정이 위험하거나 범위를 넘으면 사용자에게 즉시 보고

## 기본 절차

1. 현재 브랜치와 최신 커밋을 확인합니다.
2. `gh run list` 또는 `gh run view`로 현재 브랜치의 최신 CI run을 찾습니다.
3. `gh run watch --exit-status`로 완료까지 대기합니다.
4. 실패 시 `gh run view --log-failed`로 실패 job과 핵심 에러를 요약합니다.
5. 수정 가능한 문제만 고치고 관련 검증을 다시 실행합니다.
6. 필요 시 커밋/푸시 후 CI를 한 번 더 확인합니다.

## 자동 수정 허용 범위

- Node/Next.js
  - `pnpm lint` 실패
  - `pnpm typecheck` 실패
  - 명백한 import/path/script drift
- FastAPI
  - `uv run ruff format --check app/ tests/`
  - `uv run ruff check app/ tests/`
  - `uv run mypy app/`
- Flutter
  - `dart format --set-exit-if-changed lib/ test/`
  - `flutter analyze`

## 자동 수정 금지 범위

- 스키마/마이그레이션 변경
- 새 의존성 추가
- 대규모 리팩터
- 원인 불명 테스트 flaky 대응
- secrets, 배포 설정, 외부 서비스 설정 변경

## 보고 형식

```
## CI Watch

### Latest run
- workflow:
- branch:
- status:

### Failed jobs
- job: 원인 요약

### Auto-fix applied
- 파일/수정 내용

### Remaining blockers
- 수동 확인 필요 항목
```
