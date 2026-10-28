# ElevenLabs 최신 모델과 HaruKoto N5 적용 조사

> **조사 시점 보존:** 이 문서의 최신 모델·가격·미실행 표시는 10월 26일 조사 기준이다. 이번 갱신에서 공급업체 문서나 요금을 다시 조사하지 않았다. 이후 채택한 조합·완료된 운영 적용과 전체 청취 검수 경계는 [현재 상태](n5-audio-qa-current-state-2026-10-28.md)를 따른다.

조사 기준: 2026년 10월 26일 한국 시간. 공개 공식 문서와 로컬 소스만 검토했다. 로그인 계정의 모델 접근 권한·계약 요금, 실제 신규 생성·청취·품질 측정은 확인하지 않았다. 아래의 공급업체 설명과 제품 적용 판단을 구분한다.

## 결론

최신 품질 후보는 Eleven v4다. 먼저 화자별 실제 voice ID 전달 문제를 고치고, 같은 일본어 대사와 두 voice로 현재 Multilingual v2와 v4의 제한된 비교 샘플을 평가하는 방향을 권한다. 기존 448개 자산의 모델명 변경이나 전체 재생성은 실행하지 않는다. N5 학습효과·발음 정확도 우위를 공식 소개만으로 확정하지 않는다.

## 최신 버전과 용도

2026년 9월 28일 공식 변경 기록은 eleven_v4와 eleven_v4_turbo의 제공을 발표했다. v4는 콘텐츠용 Text to Dialogue, Turbo는 실시간 Text to Dialogue WebSocket으로 안내한다. 이는 최신 출시 확인이며 페이지에 없는 별도 GA 라벨을 추정하지 않는다. [공식 출시 기록](https://elevenlabs.io/docs/changelog/2026/9/28)

| 후보            | 공식 문서의 위치                                  | HaruKoto 판단                                       |
| --------------- | ------------------------------------------------- | --------------------------------------------------- |
| Eleven v4       | 최신 품질·표현력 중심, 일본어 포함 90개 이상 언어 | 사전 생성 대화의 우선 비교 후보                     |
| Eleven v4 Turbo | 같은 계열의 실시간 모델                           | 캐시 레슨의 우선순위는 낮고 실시간 회화는 별도 검토 |
| Eleven v3       | 표현력·다중 화자 지원, 2026-02-02 일반 제공 발표  | v4 비교가 불만족일 때 추가 후보                     |
| Multilingual v2 | 일관성·긴 음성의 안정성 중심                      | 현재 자산과 비교할 기준 모델                        |
| Flash v2.5      | 속도·비용 중심                                    | 품질 향상만을 위한 우선 교체 후보는 아님            |

공식 모델 분류에 기초한 비교다. [모델 목록](https://elevenlabs.io/docs/overview/models), [v3 일반 제공 발표](https://elevenlabs.io/blog/eleven-v3-is-now-generally-available)

## 품질 개선 가능성과 확인할 한계

v4 공식 가이드는 더 자연스러운 표현과 화자 보존, 다른 언어 생성 시 대상 언어의 자연스러운 억양을 지향한다고 설명한다. 다만 음성 학습 자료의 잡음·음량·발음 결함까지 반영할 수 있으며 태그 제어도 계속 개선 중이라고 밝힌다. Stability·Similarity를 사용하고 Style·Speed 슬라이더와 SSML은 지원하지 않는다. 현재 서버의 v2용 설정을 그대로 옮기지 않는다. [v4 가이드](https://elevenlabs.io/docs/overview/capabilities/text-to-speech/eleven-v4)

조사한 공식 자료에서 N5 장음·촉음·조사·고저 악센트의 정확성이나 학습 성과가 기존 모델보다 높다는 독립적인 일본어 측정은 확인하지 못했다. 이는 전 세계에 연구가 없다는 주장이 아니라 이번 공식 자료 조사의 범위다. 과한 감정·웃음·겹침·배경 효과를 기본 학습 음성에 추가하지 않고 읽기 정확성·화자 구분·일관성·편한 속도를 청취 기준으로 삼는다.

Voice Library는 일본어로 학습된 음성, Conversational/Educational 용도, 성별 등을 필터링할 수 있다. 무료 계정의 API 제한과 음성 공유 중단 notice 조건도 있어 실제 계정의 사용 권한·장기 접근을 확인해야 한다. 이번에는 특정 유료 voice를 추가하거나 계정 설정을 조회하지 않았다. [공식 Voice Library 안내](https://elevenlabs.io/docs/eleven-creative/voices/voice-library)

## API와 현재 코드의 차이

Text to Dialogue는 text와 voice_id 쌍의 inputs를 받는다. 현재 reference의 기본 모델은 eleven_v3여서 v4는 model_id로 명시해야 한다. 구체 reference는 고유 voice 최대 10개·전체 입력 2,000자 이하 권장을 제시한다. 모델 단독 최대 길이와 endpoint의 안정적인 요청 크기는 구분한다. seed도 완전한 결정성을 보장하지 않는다. [Create dialogue](https://elevenlabs.io/docs/api-reference/text-to-dialogue/convert)

최신 공식 quickstart는 text_to_speech.convert에 model_id=eleven_v4를 명시하는 코드 예시를 제공하고 제품 FAQ도 Create speech·Stream speech의 지원을 확인한다. 따라서 한 줄 비교는 기존 TTS 경로의 모델별 설정·실제 계정 호환을 먼저 확인한다. 초기 모델 개요의 Dialogue 경로 안내를 유일한 지원 endpoint로 해석하지 않는다. [공식 quickstart](https://elevenlabs.io/docs/eleven-api/guides/cookbooks/text-to-speech), [제품 FAQ](https://elevenlabs.io/docs/eleven-creative/playground/text-to-speech) 대화 전체 API 결과를 기존 한 줄 URL에 연결하면 재생 범위가 달라진다. 타임스탬프 응답의 voice_segments와 dialogue_input_index로 분할을 설계할 수 있으나 경계·잘림·겹침 검수가 필요하다. [타임스탬프 응답](https://elevenlabs.io/docs/api-reference/text-to-dialogue/convert-with-timestamps)

공식 개요도 여러 생성이 필요할 수 있다고 설명한다. 재생성 비용·음성 품질 편차를 고려해 유료 생성 수를 제한해야 한다. [Text to Dialogue 개요](https://elevenlabs.io/docs/overview/capabilities/text-to-dialogue)

## HaruKoto에서 확인한 사실

- 앞선 10월 26일 공개 스냅샷의 N5 캐시 448개는 모두 eleven_multilingual_v2이며 대화 198개·문제 안내 250개다. config의 기본값 eleven_flash_v2_5가 현재 운영 실행값이나 과거 자산의 모델을 뜻하지 않는다.
- SDK 최소 요구는 elevenlabs>=2.39.0, lock과 로컬 설치는 2.39.0이다. 기본 Dialogue와 timestamps 메서드는 이미 있지만 최신 옵션은 이 버전에서 지원되는지 따로 확인해야 한다. 기본 Dialogue 접근만을 위해 SDK 업그레이드가 반드시 필요하다고 단정하지 않는다.
- 현재 resolver와 서비스는 대사의 voice alias를 실제 생성기로 전달하지 않고 ElevenLabs도 단일 기본 voice ID를 사용한다. 모델 업그레이드만으로 두 인물의 목소리가 분리되지 않는다.
- 캐시에는 실제 voice ID가 없으며 기존 파일이 있으면 반환한다. 새 모델을 설정해도 이미 캐시된 음성은 그대로다.
- reading.audioUrl·content voice_id 변경은 모바일 lessonContentSignature에 포함돼 기존 로컬 레슨 복원을 무효화할 수 있다. 내용과 signature를 그대로 두는 문장별 캐시 교체를 우선 검토한다. 전체 듣기는 별도 호환 설계 대상이다.

이는 코드와 기존 공개 스냅샷 조사다. 새 운영 조회·음성 생성·사용자 기록 쓰기·Data API 설정 변경은 하지 않았다. [화자별 수정안](n5-dialogue-speaker-voices-2026-10-26.md)에 범위를 구분했다.

## 비용과 비교 계획

현재 공식 API 공개 단가는 1,000자당 v4·v3·Multilingual v2가 각각 USD 0.08, v4 Turbo·Flash/Turbo가 USD 0.04로 표시된다. 세금·계약·voice별 조건을 포함한 최종 청구액은 미확인이다. 최신 API 페이지는 USD 과금이며 오래된 크레딧 기반 Creative 설명과 섞지 않는다. 실제 계정 계약·voice별 조건·재시도·생성 횟수는 미확인이라 최종 청구액으로 제시하지 않는다. [API 요금표](https://elevenlabs.io/pricing/api)

1. 기존 음성을 참고로 보존하고 HN5-004 네 줄의 동일 원문·동일 두 voice를 고른다.
2. 두 voice를 연결한 Multilingual v2 기준 샘플과 v4 후보를 새 객체로 생성하는 비용 상한을 먼저 정한다. 아직 실행하지 않는다.
3. 모델명을 가린 비교에서 문장 누락·추가, 읽기·장음·촉음·조사, 구분·일관성, 과한 감정, 속도·음량·잘림을 평가한다. 발음은 숙련 검수자가 판단한다.
4. 합격한 경우에만 네 개 운영 캐시 행의 별도 적용안을 제시한다. 전체 198대화·250문제는 자동 확대하지 않는다.
5. 전체 대화 듣기는 별도 실험으로 두고 기존 로그인·학습·저장 레슨 이어하기를 보존한다.

이 순서는 조사에 기반한 제안이다. 새 음성 생성·설정·의존성·공개 API·DB 변경·운영 배포를 승인하거나 완료한 기록이 아니다.
