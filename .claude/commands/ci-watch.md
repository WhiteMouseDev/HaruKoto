푸시 후 CI/CD를 감시하고, 실패 시 자동으로 수정합니다.

## 워크플로우
1. `gh run list`로 최신 CI run ID 확인
2. `gh run watch {id} --exit-status`로 결과 대기
3. 성공 시 → 사용자에게 보고
4. 실패 시 → `gh run view {id} --log-failed`로 에러 분석 → 자동 수정 → 재푸시 → 1번으로 돌아감
5. 최대 3회 반복 후에도 실패 시 → 사용자에게 보고하고 수동 개입 요청

## 자동 수정 대상
- dart format 실패 → `dart format lib/ test/` 실행 후 커밋
- flutter analyze 실패 → 에러 메시지 기반 수정 후 커밋
- ruff format 실패 → `uv run ruff format` 실행 후 커밋
- test 실패 → 실패 테스트 분석 후 수정 시도

## 자동 수정 불가 시
- 사용자에게 에러 로그 요약 보고
- 수동 수정 필요 항목 정리
