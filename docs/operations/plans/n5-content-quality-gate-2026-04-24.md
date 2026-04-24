# N5 콘텐츠 품질 게이트

> 작성일: 2026-04-24
> 대상: `packages/database/data/lessons/n5/`
> 목적: N5 파일럿 레슨을 확대하기 전에 콘텐츠 데이터가 프로덕션 검수에 들어갈 수 있는 상태인지 반복 확인한다.

## 1. 배경

기존 `lessons:validate`는 레슨 JSON의 구조와 참조 무결성을 확인한다. 이번 게이트는 그 위에 운영 품질 신호를 추가한다.

- `FAIL`: 시드, 학습 진행, 채점, 참조 연결을 깨뜨릴 수 있는 데이터 오류
- `WARN`: 현재 앱은 동작하지만 파일럿/프로덕션 품질 전에 검수해야 하는 콘텐츠 리스크
- `PASS`: 기준을 충족한 영역

## 2. 실행 명령

```bash
pnpm --filter @harukoto/database lessons:quality -- --level N5
```

경고까지 배포 차단 신호로 보고 싶을 때는 strict 모드를 사용한다.

```bash
pnpm --filter @harukoto/database lessons:quality -- --level N5 --strict-warnings
```

## 3. 현재 스냅샷

2026-04-24 로컬 실행 기준:

| 항목 | 값 |
|---|---:|
| overall | WARN |
| chapters | 6 |
| lessons | 30 |
| questions | 150 |
| reading script lines | 120 |
| vocabulary links | 176 |
| grammar links | 30 |
| checks | 6 PASS / 1 WARN / 0 FAIL |

## 4. 현재 판정

| Status | 영역 | 판단 |
|---|---|---|
| PASS | Data load | N5 lesson/reference JSON 파일 로딩 성공 |
| PASS | Chapter metadata | 챕터/레슨 번호, lesson count, lesson id 중복 없음 |
| PASS | Reference links | `vocab_orders`, `grammar.grammar_order`가 기준 vocabulary/grammar 데이터에 연결됨 |
| PASS | Reading script | 30레슨 모두 speaker, voice id, 일본어 본문, 한국어 번역 포함 |
| PASS | Questions | 150문항 모두 타입별 구조와 정답 키가 유효함 |
| PASS | Learning quality heuristics | 객관식/빈칸 문제 정답 option이 `a/b/c/d = 30/30/30/30`으로 분산됨 |
| PASS | Learning quality heuristics | 기준 문법명과 다른 레슨용 친화 표기는 `grammar_order`별 alias로 명시됨 |
| WARN | Publish status | N5 6개 챕터 파일이 여전히 `meta.status: DRAFT` |

## 5. 후속 처리 기준

1. `FAIL`이 있으면 데이터 수정 전까지 seed/배포 게이트로 사용한다.
2. `WARN`은 파일럿 확대 전 콘텐츠 검수 큐로 본다.
3. 레슨용 문법 친화 표기는 `grammar_order` alias 목록에 명시된 경우만 허용한다.
4. `DRAFT` 상태는 `PILOT` 전환 또는 seed publish 정책 명시 중 하나로 결정한다.

## 6. Out of Scope

- 원어민 검수, TTS 생성, 어드민 편집 UI는 별도 후속 phase로 분리한다.
- `PILOT` 상태 전환은 별도 데이터 정책 작업으로 분리한다.
