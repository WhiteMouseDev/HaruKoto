# 통합 코드 기준 학습일 인정 ON 검증본

## 경계

운영 변경이 아니라 #216의 별도 source ON 검증본이다. 통합 OFF `92b810d44cc1ffa2ff96ab34a4fed1ba421fe48f`를 포함하며 #217의 완료 보호·계정별 목표와 #218의 STOP/클라이언트 재시도를 보존한다. 기존 #216 head `ef744b59`의 이력을 유지하고 두 학습일 인정 상수만 ON이다. 두 STOP 상수는 OFF다.

API `ANSWERED_STUDY_DAY_RECOGNITION_ENABLED=True`, 웹 같은 상수 `true`가 차이의 전부인 runtime 변경이다. 새로운 DB/API/env 계약이나 운영 활성화를 추가하지 않는다. 기존 문서의 통합 OFF 결과는 이 ON head의 검증으로 재사용하지 않는다.

## 검증

이 exact source head에서 API 전체·필수 PostgreSQL290·OpenAPI/소비자 계약과 웹 필수완료31·STOP5suite·전체회귀·native 빌드를 별도 실행한다. 로컬QA에서 ON 정책을 명시한 시뮬레이터 결과도 source commit과 구분해 기록한다. 운영 DB·인증·기존 앱 설치/계정에 쓰기 검증하지 않는다.

## 적용·복구

운영 승인은 별도다. 자동 배포 통제·구 운영 전용 STOP·구 주소 차단·실제 실행 종료 확인·p6·통합 OFF 배포/검증을 먼저 완료해야 한다. 이 ON 검증본을 p6 전 운영에 배포하거나 검증 브랜치를 main으로 자동 승격하지 않는다.

활성화 후 문제가 있으면 통합 OFF 코드로 새 학습일 인정만 중지한다. 과거 기록·마커·receipt·기한·목표·음원·로그인·Data API 차단은 보존하고 구 잠금 writer로 복귀하지 않는다.

현재 상태: exact head 검증 준비 중. 실제 결과와 CI는 PR 본문에 head별로 기록한다.
