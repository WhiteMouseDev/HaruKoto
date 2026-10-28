---
raised_by: codex-root
raised_at: 2026-10-26T17:10:34+09:00
phase: n5-audio-qa
severity: warn
status: resolved
resolved_at: 2026-10-28T13:09:15+09:00
---

## Resolution

사용자는 후속 샘플을 듣고 남성 Kenzo·여성 Shizuka v4를 채택했다. 지정 HN5-004 새 객체 4개 업로드·캐시 4행 갱신을 별도로 승인해 10월 27일 적용했고, PR #196 병합·서버 배포·두 역할 설정 활성화도 별도로 승인해 10월 28일 완료했다. PR #197은 문장 음원의 순차 전체 듣기를 구현했다. 이 결정 요청은 해결됐으며 추가 운영 변경 승인 대기로 남기지 않는다.

전체 448개 음원의 사람·일본어 검수는 별도 미완료 품질 과제로 유지한다. 이 escalation의 종료는 전체 음성 PASS나 추가 생성·캐시 교체 승인이 아니다. [현재 상태와 대표 링크](../../docs/operations/plans/n5-audio-qa-current-state-2026-10-28.md), [운영 결과·원복](../../docs/operations/plans/n5-selected-voice-production-rollout-2026-10-28.md)을 따른다.

## Original request — 2026-10-26

아래 미승인·미적용 표현은 당시 요청 이력으로 보존한다.

## What happened

사용자 기본 재생 확인은 통과했지만 두 화자가 동일 여성 목소리로 들리는 FLAG가 남았다. 콘텐츠의 역할 alias가 ElevenLabs의 실제 voice 선택에 전달되지 않으며 기존 캐시도 같은 파일을 반환한다. 최신 모델 조사까지 완료하되 유료 생성·설정·DB 쓰기는 아직 하지 않는다.

## Decision required

후속 구현에서 레슨 전용 두 voice 설정 계약과 실제 voice 선택, 네 줄 샘플의 모델·반복 수·비용 상한을 결정해야 한다. 청취 합격 뒤에도 지정 네 캐시 행의 조건부 교체는 구체 적용안 확인이 필요하다. 사용자가 이번에 승인한 것은 공식 문서 조사·보고이며 이 새 설정·비용·DML을 묵시 승인으로 해석하지 않는다.

## Options considered

1. 현재 모델에서 화자 연결을 우선 복구하고 같은 두 voice로 v4와 네 줄 비교한다.
2. 모델만 변경한다. 단일 voice 고정과 기존 캐시를 해결하지 못하므로 권하지 않는다.
3. 대화 전체를 즉시 생성해 reading.audioUrl에 넣는다. 기존 레슨 체크포인트 signature 영향과 새 재생 검토가 있어 분리한다.

## Recommended direction

첫 안을 권한다. 공개 API 응답·DB 스키마를 유지하는 범위부터 준비하고 새 env 계약·유료 생성·네 행 캐시 DML은 각각 실제 실행 전에 범위를 확인한다. 기존 198개 대화를 자동 cache miss로 만들거나 전체 재생성하지 않는다.

## Side effects

변경 시 backend의 레슨 음성 해석·제공업체 adapter·회귀가 필요하다. 프로필 지문이 있는 새 객체·생성 manifest와 private 이전 값 백업을 사용하고 기존 파일을 보존한다. 앱 콘텐츠와 voice alias를 바꾸지 않아 저장된 레슨 복원을 유지한다. 학습 기록·로그인·기한·권한·Data API는 변경 대상이 아니다.

[구체 수정안](../../docs/operations/plans/n5-dialogue-speaker-voices-2026-10-26.md), [공식 모델 조사](../../docs/operations/plans/elevenlabs-model-research-2026-10-26.md).
