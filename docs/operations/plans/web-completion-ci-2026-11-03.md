# 웹 완료 회귀 31개 CI 실행과 누락 방지

2026-11-03 사용자는 완료 회귀를 CI에 추가하고 운영 코드와 호환되는 STOP 처리를 별도 PR로 준비하도록 승인했다. 이 문서는 #217의 CI 보완에 해당한다. 운영 DB·설정·main 병합·배포는 하지 않는다.

## 변경

- 기존 frontend job에서 `quiz-completion-atomicity`·`study-activity-routes`·`quiz-session-routes` 3파일을 실행한다. 현재 합계 93개이고 그중 새 완료 원자성 회귀가 정확히 31개다.
- Vitest JSON 결과를 검사해 필수 31개가 각각 한 번씩 passed여야 한다. 삭제·skip/pending/todo·중복 대체·보고서 누락/변조·실패를 CI 실패로 처리한다. 단순 테스트 총수만 비교하지 않는다.
- 필수 결과 검사기의 자체 회귀 8개도 frontend job에서 실행한다.
- workflow/검사기 파일만 수정해도 frontend 검사를 실행하도록 경로 필터를 추가한다.
- PR 대상 필터에 기존 main과 함께 `codex/lesson-study-day-compatibility` 한 개를 추가한다. #217에서도 통합 전 GitHub Actions를 실행하기 위한 범위이며, push 트리거는 계속 main만이다. Deploy API workflow를 변경하지 않는다.

## 로컬 검증

실제 CI에 넣은 3파일 명령으로 **93개 통과**, JSON 검사에서 **필수 31개 skip 없이 통과**, 결과 검사기 자체 **8개 통과**를 확인했다. 로그/보고서는 `/private/tmp/harukoto-web-ci-stop-20261103/`에 보관한다. 원격 CI는 이 변경을 #217에 올린 뒤 해당 head의 결과로 따로 확인한다.

이 CI 명령은 기존 전체 웹 테스트의 실패 7개를 수정하거나 숨긴 전체 성공 결과가 아니다. 이번 변경에 필요한 정상 회귀를 필수화한다. 웹 실제 PostgreSQL 18개는 앞선 수동 격리 검증이며 여기 실행하는 93개에 포함됐다고 설명하지 않는다.

## STOP PR과 분리

STOP은 운영 API의 `26a81bce` 및 같은 서버/웹 소스를 가진 main `363b1661`에서 분리해 준비한다. 학습일 p6 모델·새 잠금·#217 완료 수정·로컬 폰트 변경을 STOP에 섞지 않는다. #217 CI 보완을 STOP PR과 함께 운영에 배포하지 않는다.

이 CI 변경의 롤백은 추가한 frontend 단계·검사기·해당 PR 대상 필터를 소스로 되돌리는 것이다. 운영 DB·앱 데이터·Data API 설정의 롤백은 필요하지 않다.
