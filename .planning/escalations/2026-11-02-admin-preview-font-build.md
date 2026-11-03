---
raised_by: codex-root
raised_at: 2026-11-02
phase: lesson-study-day-release-readiness
severity: warn
status: resolved
resolved_at: 2026-11-02
---

## Resolution — 고정 로컬 폰트로 원인 제거

사용자가 폰트 빌드 수정을 승인한 뒤 웹·관리자·랜딩의 Google loader를 기존과 바이트가 같은 공식 WOFF2 Unicode 분할 자산으로 교체했다. 새 의존성/Next 버전/환경 변수/운영 설정은 바꾸지 않았다. Google 호스트 차단·clean 기본 Turbopack 세 앱 빌드, 자산 248개 무결성/4개 회귀·실제 HTTP SHA/cache·브라우저 한/일 4굵기 표본을 통과했다. 폰트 수정된 최종 활성화 head의 Preview는 별도로 확인해 PR에 기록한다. 성공할 때까지 재빌드하는 것으로 해결 처리하지 않는다. [상세 결과와 운영안](../../docs/operations/plans/study-day-font-fix-and-rollout-2026-11-02.md)을 따른다. 아래는 이전 Preview 성공/실패 조사 이력이다.

## Previous resolution

2026-11-02 읽기 확인에서 직전 PR #215 head `659aac68`의 관리자·웹·랜딩 Vercel 상태는 모두 성공이었다. 이 재발 위험 때문에 이번 학습일 구현을 보류하거나 폰트/Next/클라우드를 변경할 결정은 필요하지 않다. 원래 upstream 문제가 고쳐졌다는 의미는 아니며, 새 head에서 재발하면 별도 후속으로 다시 조사한다. 아래 원인·선택지는 이력으로 보존한다. 새 한 문항 코드의 CI는 그 head에서 별도 확인한다.

## What happened

PR #215의 GitHub frontend/admin-e2e/backend/API 계약/스키마 검사는 통과했지만, 관리자 Vercel Preview가 변경하지 않은 `Noto_Sans_JP` Google font 빌드에서 실패했다. 기능 구현·격리 검증은 완료했으며 이 별도 배포 위험 때문에 학습일 코드나 운영 설정을 임의로 바꾸지 않는다.

## Decision required

운영 적용 전 별도 비운영 Preview 재확인과 폰트/Next 유지보수 작업의 범위를 정한다. 현재 승인받은 범위는 학습일 구현·로컬 검증이며 Next 버전·브랜드 폰트·클라우드 설정 변경과 운영 배포 승인은 아니다.

## Options considered

1. 운영을 건드리지 않는 Preview 재시도를 먼저 검토한다. 성공해도 간헐적 결함이 사라진 것으로 단정하지 않는다.
2. 별도 PR로 기존 글꼴을 적법하게 로컬 패키징하거나, 수정이 포함된 안정 Next 버전을 정확히 확인해 업그레이드·전 소비자 검증한다.
3. webpack으로만 바꾼다. 설치된 webpack font loader도 URL 확장자를 가정해 같은 확장자 없는 URL에 안전하지 않으므로 영구 대안으로 권하지 않는다.

## Recommended direction

학습일 PR과 분리해 비운영 Preview 재확인안을 먼저 제시하고, 폰트 외부 다운로드 의존성 제거 또는 수정 안정 버전 도입을 후속 유지보수로 검토한다. 실제 Next/폰트/클라우드 변경은 구체안 승인 뒤 수행한다. 학습일 운영 적용안은 새 [한 문항 구현 기록](../../docs/operations/plans/answered-study-day-policy-implementation-2026-11-02.md)의 호환 배포 전 쓰기 통제·종료 확인 순서를 따른다.

## Evidence and side effects

실패 로그의 폰트 요청 248건(고유 124개)은 확장자 없는 `fonts.gstatic.com/l/font` URL에 `kit`, `skey`, `v` 쿼리가 포함되어 있었다. 직렬화한 옵션의 `&`를 Turbopack이 추가 쿼리로 해석해 `queries have exactly one entry`와 내부 font module 미해결 오류가 났다. admin layout·Next 버전·lockfile은 기준 main과 동일하다. [공식 이슈 #99114](https://github.com/vercel/next.js/issues/99114)와 [병합된 upstream 수정 #100158](https://github.com/vercel/next.js/pull/100158)을 참고하며, 실제 적용할 안정 버전은 아직 확정하지 않았다.

영향 범위는 관리자 Preview와 향후 웹 계열 빌드 안정성이다. 이번에 API/DB·사용자 기록·권한·Data API·음원·실기기를 변경한 문제는 아니다. 기능 검증 수, 원격 CI 통과와 별도 미리보기 실패는 [작업 기록](../../docs/operations/plans/lesson-study-day-recognition-implementation-2026-11-02.md)에 분리했다. 토큰·전체 빌드 로그·비공개 배포 URL을 저장소에 넣지 않는다.
