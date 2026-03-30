# Phase 6: TTS Per-Field Audio - Research

**Researched:** 2026-03-30
**Domain:** DB migration (Alembic) + FastAPI schema change + React/TanStack Query hook refactor
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** TtsAudio 테이블에 `field` 컬럼(Text, NOT NULL) 추가. 업계 표준 3단계 마이그레이션: 1) field 컬럼 추가(nullable) → 2) 기존 데이터를 target_type별 기본 필드로 backfill (vocabulary→'reading', grammar→'pattern', cloze→'sentence', sentence_arrange→'japanese_sentence', conversation→'situation') → 3) NOT NULL 제약 + UniqueConstraint 변경
- **D-02:** UniqueConstraint를 `(target_type, target_id, speed, field)` 4컬럼으로 변경. 같은 아이템의 여러 필드에 각각 독립 오디오 저장 보장
- **D-03:** 메인 앱(tts.py) 호환성도 이 Phase에서 함께 처리. 스키마 변경과 코드 호환을 분리하면 배포 사이 깨질 위험. tts.py의 기존 쿼리가 필드별 복수 레코드에서 MultipleResultsFound 에러를 내지 않도록 수정
- **D-04:** GET `/{content_type}/{item_id}/tts` 엔드포인트를 필드별 맵 응답으로 변경: `{audios: {reading: {audio_url, provider, created_at}, word: null, ...}}`. 복합 리소스의 하위 리소스를 맵으로 반환하는 REST 표준 패턴. 프론트엔드가 1회 요청으로 모든 필드 상태 파악
- **D-05:** POST `/tts/regenerate`는 현재 단일 필드 재생성 패턴 유지. body에 field 필드가 이미 있으므로 변경 없음. 응답에 regenerated field 정보 포함
- **D-06:** 새로 생성하는 오디오의 GCS 경로: `tts/admin/{content_type}/{item_id}/{field}.mp3`. GCS/S3 prefix-based hierarchy 표준 패턴
- **D-07:** 기존 GCS 파일({item_id}.mp3)은 이동하지 않음. DB의 audio_url이 절대 URL이므로 기존 레코드는 그대로 동작. 재생성 시 자연스럽게 새 경로로 교체
- **D-08:** grammar에 `example_sentences` 필드 추가 (pattern + example_sentences = 2개). 나머지 콘텐츠 타입은 현재 tts-fields.ts 정의 유지
- **D-09:** 백엔드(Python)에도 동일한 TTS_FIELDS 정의 추가. API가 유효한 field 값을 검증하는 단일 소스 오브 트루스 패턴

### Claude's Discretion

- Alembic 마이그레이션 파일 세부 구현 (revision ID, 트랜잭션 처리)
- 메인 앱 tts.py 호환성 수정 범위 (최소한의 변경)
- 프론트엔드 useTtsPlayer 훅의 필드별 상태 관리 방식 (단일 audioUrl → 필드별 맵)
- TtsPlayer 컴포넌트의 필드별 로딩/에러 상태 표시 방식
- Pydantic 스키마 변경 세부 구조 (AdminTtsResponse → AdminTtsMapResponse)
- pytest / Vitest 테스트 범위

### Deferred Ideas (OUT OF SCOPE)

- BATCH-01: TTS 일괄 재생성 (여러 항목 동시 재생성) — REQUIREMENTS.md에 Future로 분류
- GCS orphan cleanup job — 재생성 시 이전 경로 파일이 GCS에 남음. 별도 cleanup 작업으로 처리
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TTS-03 | 단어 편집 화면에서 읽기/단어/예문 필드별로 개별 TTS 오디오를 생성할 수 있다 | D-01~D-09 전체 구현으로 달성. TtsAudio.field 컬럼 + UniqueConstraint 변경이 필드별 독립 저장을 가능하게 함 |
| TTS-04 | 필드별 오디오가 독립적으로 재생/재생성된다 (다른 필드에 영향 없음) | D-02 UniqueConstraint + D-04 맵 응답 + useTtsPlayer 훅 리팩토링으로 달성. 재생성 시 해당 field row만 DELETE→INSERT |
| TTS-05 | 기존 아이템당 1개 오디오 데이터가 마이그레이션 후에도 정상 동작한다 | D-01 3단계 마이그레이션(backfill→NOT NULL)으로 달성. 기존 레코드 field='reading'(vocabulary) 등 기본값으로 보존 |
</phase_requirements>

---

## Summary

Phase 6는 `tts_audio` 테이블에 `field` 컬럼을 추가하는 스키마 확장과, 해당 변경을 전체 스택에 걸쳐 전파하는 작업이다. 현재 아이템당 1개 오디오(UniqueConstraint: target_type, target_id, speed)를 아이템당 필드별 1개(UniqueConstraint: target_type, target_id, speed, field)로 확장한다.

기존 코드 분석 결과, 이 Phase의 핵심 위험은 세 가지다. (1) tts.py의 `scalar_one_or_none()` 쿼리 — field 컬럼 추가 후 vocabulary 아이템에 reading/word/example_sentence 3개 레코드가 생기면 `scalar_one_or_none()`이 `MultipleResultsFound`를 던진다. (2) admin_content.py의 `get_admin_tts`와 `regenerate_admin_tts` — 동일 패턴으로 field 필터 없이 조회·삭제하므로 수정 필요. (3) 기존 Vitest 테스트(`tts-player.test.tsx`)가 `audioUrl: string | null` 단일 값을 mock하고 있어, `audios: Record<string, AudioInfo | null>` 맵으로 변경 시 모두 업데이트 필요.

**Primary recommendation:** Wave 1에서 Alembic 마이그레이션(3단계) + 백엔드 API 변경을 원자적으로 처리하고, Wave 2에서 프론트엔드 훅/컴포넌트/테스트를 업데이트한다. 두 Wave는 순차 의존성을 갖는다.

---

## Standard Stack

### Core (모두 이미 프로젝트에 설치됨)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Alembic | >=1.14 | DB 스키마 마이그레이션 DDL 권한 | 프로젝트 DDL 권한은 Alembic ONLY (api-plane.md) |
| SQLAlchemy[asyncio] | >=2.0 | 비동기 ORM | 기존 FastAPI 런타임 ORM |
| FastAPI/Pydantic | >=0.115 / >=2.10 | API 엔드포인트 + 응답 스키마 | 기존 스택 |
| TanStack Query | ^5.90.21 | 프론트엔드 서버 상태 | 기존 훅 패턴 (useTtsPlayer) |
| Vitest + Testing Library | ^4.0.18 / ^16.3.2 | 프론트엔드 단위 테스트 | `apps/admin/vitest.config.ts` 존재 |
| pytest + pytest-asyncio | >=8.3 / >=0.25 | 백엔드 API 테스트 | `apps/api/tests/test_admin_tts.py` 존재 |

**Installation:** 신규 패키지 설치 불필요. 모든 의존성 이미 존재.

---

## Architecture Patterns

### 현재 상태 (Phase 6 이전)

```
TtsAudio 테이블:
  id | target_type | target_id | text | speed | provider | model | audio_url | created_at
  UniqueConstraint: (target_type, target_id, speed)  ← 아이템당 1개만

GET /{content_type}/{item_id}/tts
  → AdminTtsResponse { audioUrl, field(=text), provider }  ← 단일 응답

POST /tts/regenerate
  → DELETE WHERE (target_type, target_id, speed)  ← field 무관 전체 삭제
  → INSERT new row
  → AdminTtsResponse { audioUrl, field, provider }

useTtsPlayer
  → ttsQuery.data.audioUrl: string | null  ← 단일 URL
  → handlePlayPause: field로 구분은 하나, URL은 항상 같은 단일 audioUrl 사용

TtsPlayer
  → hasAudio = !!audioUrl  ← 단일 boolean, 모든 필드에 동일 적용
```

### 목표 상태 (Phase 6 이후)

```
TtsAudio 테이블:
  id | target_type | target_id | text | speed | provider | model | audio_url | field | created_at
  UniqueConstraint: (target_type, target_id, speed, field)  ← 필드별 1개

GET /{content_type}/{item_id}/tts
  → AdminTtsMapResponse { audios: { reading: {audioUrl, provider, createdAt} | null, word: null, ... }}

POST /tts/regenerate
  → DELETE WHERE (target_type, target_id, speed, field)  ← 해당 필드만 삭제
  → INSERT new row (field 포함)
  → AdminTtsResponse { audioUrl, field, provider }  ← 변경 없음 (D-05)

useTtsPlayer
  → ttsQuery.data.audios: Record<string, AudioInfo | null>  ← 필드별 맵
  → handlePlayPause(field): 필드별 URL 조회

TtsPlayer
  → hasAudio(field) = !!audios[field]  ← 필드별 boolean
```

### Pattern 1: 3단계 Alembic 마이그레이션 (D-01)

**What:** nullable 추가 → backfill → NOT NULL + 제약 변경을 단일 마이그레이션 파일에서 3단계로 수행
**When to use:** 기존 데이터가 있는 NOT NULL 컬럼 추가 시 항상 사용

```python
# Source: Alembic 표준 패턴 (verified from existing e5f6g7h8i9j0 migration)

def upgrade() -> None:
    # Step 1: nullable field 컬럼 추가
    op.add_column("tts_audio", sa.Column("field", sa.Text(), nullable=True))

    # Step 2: 기존 데이터 backfill (target_type별 기본 필드값)
    op.execute("""
        UPDATE tts_audio SET field = CASE target_type
            WHEN 'vocabulary'        THEN 'reading'
            WHEN 'grammar'           THEN 'pattern'
            WHEN 'cloze'             THEN 'sentence'
            WHEN 'sentence_arrange'  THEN 'japanese_sentence'
            WHEN 'conversation'      THEN 'situation'
            ELSE 'reading'
        END
        WHERE field IS NULL
    """)

    # Step 3: NOT NULL 제약 추가 + UniqueConstraint 교체
    op.alter_column("tts_audio", "field", nullable=False)
    op.drop_constraint("tts_audio_target_type_target_id_speed_key", "tts_audio")
    op.create_unique_constraint(
        "uq_tts_audio_target_field",
        "tts_audio",
        ["target_type", "target_id", "speed", "field"],
    )
```

**Revision chain:** 현재 head = `i9j0k1l2m3n4`. 신규 마이그레이션의 `down_revision = "i9j0k1l2m3n4"`.

**Critical:** UniqueConstraint 이름 확인 필요. PostgreSQL에서 자동 생성된 이름은 `{table}_{col1}_{col2}_{col3}_key` 패턴. 기존 마이그레이션 `e5f6g7h8i9j0`에서 `sa.UniqueConstraint("target_type", "target_id", "speed")` 이름 없이 생성됨 → PostgreSQL 기본 이름 `tts_audio_target_type_target_id_speed_key`.

### Pattern 2: GET 엔드포인트 필드별 맵 응답 (D-04)

**What:** 단일 `scalar_one_or_none()` → 모든 레코드 조회 후 dict로 변환
**When to use:** 복합 리소스의 하위 리소스를 한 번에 반환할 때

```python
# Source: verified from admin_content.py existing pattern + D-04 decision

# 새 Pydantic 스키마
class AudioFieldInfo(CamelModel):
    audio_url: str
    provider: str
    created_at: datetime

class AdminTtsMapResponse(CamelModel):
    audios: dict[str, AudioFieldInfo | None]

# 새 엔드포인트 구현
@router.get("/{content_type}/{item_id}/tts", response_model=AdminTtsMapResponse)
async def get_admin_tts(...):
    results = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == content_type,
            TtsAudio.target_id == item_id,
            TtsAudio.speed == 1.0,
        )
    )
    records = results.scalars().all()

    # 콘텐츠 타입별 필드 목록으로 맵 구성 (없는 필드는 None)
    field_list = TTS_FIELDS.get(content_type, [])
    audios: dict[str, AudioFieldInfo | None] = {f: None for f in field_list}
    for rec in records:
        if rec.field in audios:
            audios[rec.field] = AudioFieldInfo(
                audio_url=rec.audio_url,
                provider=rec.provider,
                created_at=rec.created_at,
            )
    return AdminTtsMapResponse(audios=audios)
```

### Pattern 3: 재생성 시 필드별 DELETE (D-05)

**What:** 기존 전체 삭제(`WHERE target_type, target_id, speed`) → 필드별 삭제(`WHERE target_type, target_id, speed, field`)

```python
# 기존 (삭제 필요):
await db.execute(
    sa_delete(TtsAudio).where(
        TtsAudio.target_type == body.content_type,
        TtsAudio.target_id == body.item_id,
        TtsAudio.speed == 1.0,
    )
)

# 변경 후:
await db.execute(
    sa_delete(TtsAudio).where(
        TtsAudio.target_type == body.content_type,
        TtsAudio.target_id == body.item_id,
        TtsAudio.speed == 1.0,
        TtsAudio.field == body.field,
    )
)

# GCS 경로도 변경 (D-06):
# 기존: f"tts/admin/{body.content_type}/{body.item_id}.mp3"
# 변경: f"tts/admin/{body.content_type}/{body.item_id}/{body.field}.mp3"

# TtsAudio INSERT에 field 컬럼 추가:
db.add(TtsAudio(
    target_type=body.content_type,
    target_id=body.item_id,
    text=text,
    speed=1.0,
    provider=tts_result.provider,
    model=tts_result.model,
    audio_url=audio_url,
    field=body.field,  # 추가
))
```

### Pattern 4: tts.py 메인 앱 호환성 수정 (D-03)

**What:** `scalar_one_or_none()`이 field 추가 후 MultipleResultsFound를 내지 않도록 수정
**Current code (tts.py line 51-58):**

```python
# 기존 (위험 — field 추가 후 vocabulary에 복수 레코드 존재 가능):
cached = await db.execute(
    select(TtsAudio).where(
        TtsAudio.target_type == "vocabulary",
        TtsAudio.target_id == vocab_id_str,
        TtsAudio.speed == 1.0,
    )
)
tts_record = cached.scalar_one_or_none()

# 수정 후 — 기본 필드(reading)로 한정:
cached = await db.execute(
    select(TtsAudio).where(
        TtsAudio.target_type == "vocabulary",
        TtsAudio.target_id == vocab_id_str,
        TtsAudio.speed == 1.0,
        TtsAudio.field == "reading",  # 추가
    )
)
tts_record = cached.scalar_one_or_none()
```

또한 tts.py의 INSERT에도 `field="reading"` 추가 필요 (line 87-95).

### Pattern 5: useTtsPlayer 훅 필드별 맵으로 리팩토링

**What:** 단일 `audioUrl: string | null` → `audios: Record<string, AudioInfo | null>`

```typescript
// Source: apps/admin/src/hooks/use-tts-player.ts (verified)

// 새 타입 (admin-content.ts에도 적용)
export type AudioFieldInfo = {
  audioUrl: string;
  provider: string;
  createdAt: string;
};

export type TtsAudioMapResponse = {
  audios: Record<string, AudioFieldInfo | null>;
};

// 훅 변경
export function useTtsPlayer(contentType: ContentType, itemId: string) {
  // ...기존 state는 그대로...

  const ttsQuery = useQuery<TtsAudioMapResponse>({
    queryKey: ['admin-tts', contentType, itemId],
    queryFn: () => fetchTtsAudio(contentType, itemId),
    staleTime: 60_000,
  });

  const audios = ttsQuery.data?.audios ?? {};

  function handlePlayPause(field: string) {
    const url = audios[field]?.audioUrl;  // 필드별 URL 조회
    if (!url) return;
    // ... 나머지 로직 동일
  }

  // regenerateMutation: onSuccess에서 newData.audioUrl → 필드 URL로 변경
  // ...

  return {
    audios,  // audioUrl 대신 audios 맵 반환
    isLoading: ttsQuery.isLoading,
    playingField,
    confirmField,
    setConfirmField,
    handlePlayPause,
    regenerateMutation,
  };
}
```

### Pattern 6: TtsPlayer 컴포넌트 필드별 상태 분기

**What:** `const hasAudio = !!audioUrl` → `const hasAudio = (field: string) => !!audios[field]`

```typescript
// TtsPlayer 내부 변경
const { audios, isLoading, ... } = useTtsPlayer(contentType, itemId);

// 각 field row에서:
{fields.map((field) => {
  const fieldAudio = audios[field.value];
  const hasFieldAudio = !!fieldAudio;

  return (
    <div key={field.value}>
      {hasFieldAudio ? <CheckCircle2 /> : <XCircle />}
      {hasFieldAudio ? (
        /* Play + Regenerate 버튼 */
      ) : (
        /* Generate 버튼 */
      )}
    </div>
  );
})}
```

### Pattern 7: TTS_FIELDS 업데이트 (D-08, D-09)

**Frontend (tts-fields.ts):**
```typescript
// grammar에 example_sentences 추가
grammar: {
  default: 'pattern',
  options: [
    { value: 'pattern', labelKey: 'fields.pattern' },
    { value: 'example_sentences', labelKey: 'fields.exampleSentences' },  // 신규
  ],
},
```

**i18n 키 추가 필요 (ja.json, ko.json, en.json):**
```json
// tts.fields에 추가
"exampleSentences": "例文"
```

**Backend (admin_content.py):**
```python
# TTS_FIELDS: content_type → valid field list
TTS_FIELDS: dict[str, list[str]] = {
    "vocabulary":       ["reading", "word", "example_sentence"],
    "grammar":          ["pattern", "example_sentences"],
    "cloze":            ["sentence"],
    "sentence_arrange": ["japanese_sentence"],
    "conversation":     ["situation"],
}

# AdminTtsRegenerateRequest에서 field 검증 시 활용
# (현재 Literal type으로 정의되어 있어 동적 검증 추가 또는 Literal 확장 필요)
```

### Anti-Patterns to Avoid

- **UniqueConstraint 이름 추측:** PostgreSQL 자동 생성 이름을 잘못 지정하면 `drop_constraint` 실패. 실제 DB에서 `\d tts_audio` 또는 information_schema로 확인 권장. 대안: `op.execute("ALTER TABLE tts_audio DROP CONSTRAINT ...")` SQL 직접 사용
- **field 컬럼 없이 INSERT:** tts.py의 기존 INSERT에 field를 추가하지 않으면 NOT NULL 제약 위반으로 런타임 에러
- **GET 엔드포인트에서 scalar_one_or_none 유지:** field 컬럼 추가 후 다중 레코드 시 MultipleResultsFound 예외 발생
- **훅 반환값 변경 없이 컴포넌트 업데이트:** TtsPlayer가 `audioUrl`을 직접 받는 코드가 있다면 undefined 에러. 훅과 컴포넌트를 같은 Wave에서 업데이트

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DB 마이그레이션 | 직접 SQL 실행 | Alembic op.add_column / op.execute | DDL 권한은 Alembic ONLY (api-plane.md) |
| 필드 유효성 검증 | 엔드포인트별 if-else | TTS_FIELDS dict (D-09) | 중앙화된 단일 소스, 프론트/백 동기화 |
| TTS 오디오 업로드 | 새 GCS 클라이언트 | `_upload_to_gcs()` (tts.py에서 import) | 이미 admin_content.py에서 import 중 |
| 재생성 확인 다이얼로그 | 새 Dialog | `RegenerateConfirmDialog` | Phase 4에서 완성, 재사용 가능 |

**Key insight:** 이 Phase는 신규 라이브러리가 없고 기존 패턴의 확장이다. 새로 만들 것보다 수정할 것이 많다.

---

## Runtime State Inventory

> Phase 6는 DB 스키마 변경(field 컬럼 추가)과 기존 레코드 backfill을 포함하므로 런타임 상태 인벤토리가 필요하다.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `tts_audio` 테이블의 기존 레코드들 — field 컬럼 없이 (target_type, target_id, speed) unique | Alembic 마이그레이션 Step 2의 UPDATE backfill로 처리. 코드 변경이 아닌 데이터 마이그레이션 |
| Live service config | GCS 버킷의 기존 파일: `tts/admin/{content_type}/{item_id}.mp3` 경로 | 이동 불필요 (D-07). DB의 audio_url이 절대 URL이므로 기존 레코드 그대로 동작 |
| OS-registered state | 없음 — OS 레벨 등록 없음 | None |
| Secrets/env vars | `GCS_BUCKET_NAME`, `GCS_CDN_BASE_URL` — 코드 변경 없음, 경로 패턴만 변경 | None (코드에서 경로 문자열만 변경) |
| Build artifacts | 없음 — 컴파일 아티팩트 해당 없음 | None |

**핵심:** 기존 `tts_audio` 레코드의 `field` 컬럼값은 반드시 backfill되어야 한다. NULL로 남겨두면 3단계의 NOT NULL 제약 추가가 실패한다.

---

## Common Pitfalls

### Pitfall 1: UniqueConstraint 이름 불일치
**What goes wrong:** `op.drop_constraint("tts_audio_target_type_target_id_speed_key", ...)` 실패로 마이그레이션 중단
**Why it happens:** PostgreSQL이 자동 생성하는 constraint 이름이 실제와 다를 경우
**How to avoid:** 마이그레이션 작성 전 `\d tts_audio` 또는 아래 쿼리로 이름 확인:
```sql
SELECT conname FROM pg_constraint
WHERE conrelid = 'tts_audio'::regclass AND contype = 'u';
```
또는 이름 대신 `op.execute("ALTER TABLE tts_audio DROP CONSTRAINT IF EXISTS ...")`  사용
**Warning signs:** `ProgrammingError: constraint "..." does not exist`

### Pitfall 2: tts.py INSERT 누락
**What goes wrong:** 마이그레이션 후 메인 앱이 새 TTS 생성 시 `NOT NULL constraint failed: tts_audio.field` 에러
**Why it happens:** tts.py line 87-95의 `TtsAudio(...)` 생성 시 field 인수를 추가하지 않음
**How to avoid:** D-03 수정 범위에 INSERT도 포함. TtsAudio 모델에 field 추가 후 IDE의 타입 에러로 확인 가능
**Warning signs:** `sqlalchemy.exc.IntegrityError` in tts.py logs

### Pitfall 3: 프론트엔드 타입 불일치
**What goes wrong:** `ttsQuery.data.audioUrl` undefined 에러 (변경 후 `audios` 맵으로 바뀜)
**Why it happens:** `TtsAudioResponse` 타입을 변경했지만 사용처를 누락
**How to avoid:** `admin-content.ts`의 타입 변경 시 TypeScript 빌드 에러로 모든 사용처 확인. `audioUrl`을 직접 참조하는 코드 검색 필요
**Warning signs:** TypeScript `Property 'audioUrl' does not exist on type 'TtsAudioMapResponse'`

### Pitfall 4: 기존 Vitest 테스트 실패
**What goes wrong:** `tts-player.test.tsx` 전체 실패 — `setupHook({ audioUrl: ... })` 패턴이 유효하지 않아짐
**Why it happens:** `useTtsPlayer` 반환값 구조가 `audioUrl` → `audios` 맵으로 변경됨
**How to avoid:** 훅 반환 타입 변경 시 테스트 mock도 함께 업데이트. `setupHook({ audios: { reading: { audioUrl: '...' } } })`
**Warning signs:** `TypeError: Cannot read properties of undefined (reading 'audioUrl')`

### Pitfall 5: grammar 필드 example_sentences backfill 혼란
**What goes wrong:** grammar 기존 레코드가 `field='pattern'`으로 backfill되는데, grammar는 이제 2개 필드. `example_sentences` 필드는 신규 생성 시 처음 추가됨
**Why it happens:** backfill은 기존 레코드(아이템당 1개)를 기본 필드로 매핑. `example_sentences`는 기존 레코드가 없으므로 null로 표시됨
**How to avoid:** 이는 올바른 동작. grammar 아이템의 기존 오디오는 `pattern` 필드로 보존, `example_sentences`는 처음부터 없던 것. TtsPlayer에서 null 처리 확인
**Warning signs:** grammar 편집 화면에서 `example_sentences` 행에 "No audio" 표시됨 — 정상 동작

---

## Code Examples

### GET 엔드포인트 응답 변환 패턴

```python
# Source: admin_content.py 기존 패턴 분석 + D-04 결정

# 기존 AdminTtsResponse 유지 (regenerate 응답으로 재사용)
class AdminTtsResponse(CamelModel):
    audio_url: str | None
    field: str | None
    provider: str | None

# 신규 GET 응답 스키마
class AudioFieldInfo(CamelModel):
    audio_url: str
    provider: str
    created_at: datetime

class AdminTtsMapResponse(CamelModel):
    audios: dict[str, AudioFieldInfo | None]
```

### 프론트엔드 fetchTtsAudio 함수 변경

```typescript
// Source: apps/admin/src/lib/api/admin-content.ts (verified)

export type AudioFieldInfo = {
  audioUrl: string;
  provider: string;
  createdAt: string;
};

export type TtsAudioMapResponse = {
  audios: Record<string, AudioFieldInfo | null>;
};

export async function fetchTtsAudio(
  contentType: string,
  itemId: string,
): Promise<TtsAudioMapResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${API_URL}/api/v1/admin/content/${contentType}/${itemId}/tts`,
    { headers },
  );
  if (!res.ok) throw new Error('Failed to fetch TTS audio');
  return res.json() as Promise<TtsAudioMapResponse>;
}
```

### 업데이트된 Vitest 테스트 mock 패턴

```typescript
// Source: apps/admin/src/__tests__/tts-player.test.tsx (verified existing)

// 기존 (변경 전):
// setupHook({ audioUrl: 'https://example.com/audio.mp3' })

// 변경 후:
function setupHook(overrides: Partial<ReturnType<typeof useTtsPlayer>> = {}) {
  mockUseTtsPlayer.mockReturnValue({
    audios: {},           // 빈 맵 = no audio
    isLoading: false,
    playingField: null,
    confirmField: null,
    setConfirmField: mockSetConfirmField,
    handlePlayPause: mockHandlePlayPause,
    regenerateMutation: { mutate: mockMutate, isPending: false } as unknown as ...,
    ...overrides,
  });
}

// 오디오 있을 때:
setupHook({ audios: { reading: { audioUrl: 'https://...', provider: 'elevenlabs', createdAt: '...' } } })
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 아이템당 1개 TTS (UniqueConstraint 3컬럼) | 아이템당 필드별 독립 TTS (UniqueConstraint 4컬럼) | Phase 6 | 필드별 오디오 독립 관리 가능 |
| GET /tts → 단일 AudioUrl 응답 | GET /tts → audios 맵 응답 | Phase 6 | 1회 요청으로 모든 필드 상태 파악 |
| GCS 경로: `{item_id}.mp3` | GCS 경로: `{item_id}/{field}.mp3` | Phase 6 (신규 생성만) | prefix 기반 계층 구조로 정리 |
| grammar TTS: pattern 1개 필드 | grammar TTS: pattern + example_sentences 2개 필드 | Phase 6 | 문법 학습 품질 향상 |

---

## Open Questions

1. **UniqueConstraint 이름 확인**
   - What we know: Alembic 마이그레이션 `e5f6g7h8i9j0`에서 이름 없이 생성됨
   - What's unclear: 실제 PostgreSQL DB에서의 constraint 이름
   - Recommendation: 마이그레이션 파일에서 `op.execute("ALTER TABLE tts_audio DROP CONSTRAINT IF EXISTS tts_audio_target_type_target_id_speed_key")` 또는 `IF EXISTS`로 안전하게 처리

2. **AdminTtsRegenerateRequest의 field Literal 타입 확장**
   - What we know: 현재 `field: str` (Literal 없음, 주석에 유효 값 나열)
   - What's unclear: `example_sentences`를 추가하면 주석도 업데이트 필요
   - Recommendation: TTS_FIELDS dict로 동적 검증 추가 또는 주석 업데이트만

3. **regenerateMutation onSuccess에서 audios 업데이트 방식**
   - What we know: 현재 `queryClient.invalidateQueries`로 전체 재조회. 또는 응답 데이터로 optimistic update 가능
   - What's unclear: 재생성 응답이 단일 AudioFieldInfo인데 audios 맵의 특정 필드만 업데이트할지 vs 전체 재조회할지
   - Recommendation: 단순성을 위해 invalidateQueries 유지 (기존 패턴과 일치, 1-3명 소규모 사용자라 성능 문제 없음)

---

## Environment Availability

> 신규 외부 도구 없음. 기존 인프라(Alembic, FastAPI, TanStack Query, Vitest) 모두 사용 중.

Step 2.6: SKIPPED — 모든 필요 도구가 기존 스택 내에 존재. 신규 외부 의존성 없음.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework (Frontend) | Vitest ^4.0.18 + Testing Library React ^16.3.2 |
| Config file (Frontend) | `apps/admin/vitest.config.ts` |
| Quick run command (Frontend) | `cd apps/admin && pnpm vitest run src/__tests__/tts-player.test.tsx` |
| Full suite command (Frontend) | `cd apps/admin && pnpm vitest run` |
| Framework (Backend) | pytest >=8.3 + pytest-asyncio >=0.25 |
| Config file (Backend) | `apps/api/pytest.ini` or `pyproject.toml` |
| Quick run command (Backend) | `cd apps/api && uv run pytest tests/test_admin_tts.py -x -q` |
| Full suite command (Backend) | `cd apps/api && uv run pytest tests/ -x -q` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TTS-03 | 필드별 오디오 생성 가능 (DB 저장 + GCS 업로드) | unit (mock) | `uv run pytest tests/test_admin_tts.py::test_regenerate_field_stores_field_column -x` | ❌ Wave 0 |
| TTS-04 | 재생성 시 해당 필드만 삭제·교체, 타 필드 보존 | unit (mock) | `uv run pytest tests/test_admin_tts.py::test_regenerate_does_not_delete_other_fields -x` | ❌ Wave 0 |
| TTS-04 | 프론트엔드 필드별 audios 맵 조회/재생 | unit (Vitest) | `cd apps/admin && pnpm vitest run src/__tests__/tts-player.test.tsx` | ✅ (수정 필요) |
| TTS-05 | GET /tts 응답에 backfill된 기존 레코드 포함 | unit (mock) | `uv run pytest tests/test_admin_tts.py::test_get_tts_returns_map_with_legacy_field -x` | ❌ Wave 0 |
| TTS-05 | 마이그레이션 backfill SQL 정확성 | migration test | manual verify via psql after migration | manual |

### Sampling Rate
- **Per task commit:** 변경된 파일의 직접 테스트 (위 quick run commands)
- **Per wave merge:** `cd apps/api && uv run pytest tests/ -x -q && cd ../../apps/admin && pnpm vitest run`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `apps/api/tests/test_admin_tts.py` — 기존 파일에 test case 추가 필요: `test_regenerate_field_stores_field_column`, `test_regenerate_does_not_delete_other_fields`, `test_get_tts_returns_map_with_legacy_field`
- [ ] `apps/admin/src/__tests__/tts-player.test.tsx` — 기존 mock 구조를 `audios` 맵으로 업데이트 필요

*(기존 테스트 인프라 존재. 신규 파일 생성 불필요, 기존 파일 수정 필요.)*

---

## Project Constraints (from CLAUDE.md)

1. **DDL 권한 Alembic ONLY:** `apps/api/alembic/`에서만 테이블 변경. Prisma DDL 금지
2. **도메인 로직 FastAPI 우선:** 어드민 TTS 로직은 FastAPI에 있음, Next.js API Route 신규 추가 금지
3. **TypeScript strict mode:** `any` 타입 금지, type alias 선호, kebab-case 파일명
4. **커밋 전 lint 필수:** `cd apps/api && uv run ruff check app/ tests/` + `cd apps/admin && pnpm lint`
5. **Codex 교차 검증:** API 계약 변경(GET /tts 응답 구조 변경)은 P0 레벨 → 커밋 전 Codex 검증 필수
6. **올바른 접근법 우선:** 임시 우회 없음. 3단계 마이그레이션 정석 사용 (D-01)
7. **CamelModel:** FastAPI는 snake_case → camelCase 자동 변환. 프론트엔드 타입은 camelCase
8. **Korean error messages:** FastAPI HTTPException detail은 한국어 (기존 패턴 유지)

---

## Sources

### Primary (HIGH confidence)
- `apps/api/app/models/tts.py` — TtsAudio 현재 스키마 (field 컬럼 없음, UniqueConstraint 3컬럼 확인)
- `apps/api/alembic/versions/e5f6g7h8i9j0_add_tts_audio_table.py` — 기존 tts_audio 마이그레이션 (revision chain 확인)
- `apps/api/alembic/versions/i9j0k1l2m3n4_add_audit_logs_table.py` — 현재 head revision 확인
- `apps/api/app/routers/admin_content.py` (lines 1025-1208) — TTS 엔드포인트 현재 구현
- `apps/api/app/routers/tts.py` — 메인 앱 TTS 라우터, scalar_one_or_none 위험 확인
- `apps/admin/src/hooks/use-tts-player.ts` — 현재 훅 구현 (audioUrl 단일 값)
- `apps/admin/src/components/content/tts-player.tsx` — 현재 컴포넌트 구현
- `apps/admin/src/lib/tts-fields.ts` — TTS 필드 정의 (grammar에 example_sentences 없음 확인)
- `apps/admin/src/lib/api/admin-content.ts` (lines 185-235) — TtsAudioResponse 타입 + fetch functions
- `apps/api/app/schemas/admin_content.py` (lines 215-231) — AdminTtsResponse, AdminTtsRegenerateRequest
- `apps/admin/src/__tests__/tts-player.test.tsx` — 기존 테스트 구조 (mock 패턴 확인)
- `apps/api/tests/test_admin_tts.py` — 기존 pytest 픽스처 패턴
- `.planning/phases/06-tts-per-field-audio/06-CONTEXT.md` — 확정된 구현 결정 D-01~D-09

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Phase 6 위험 사항 (Alembic chain, backward-compat 전략)
- `apps/admin/messages/ja.json` — 기존 i18n 키 구조 (tts.fields 섹션)

---

## Metadata

**Confidence breakdown:**
- DB 마이그레이션: HIGH — 기존 코드와 Alembic 마이그레이션을 직접 분석, 3단계 패턴은 동일 코드베이스에서 확인
- API 변경: HIGH — 현재 엔드포인트 구현 전체 확인, 변경 범위 명확
- 프론트엔드 훅/컴포넌트: HIGH — 현재 구현 전체 확인, 변경 포인트 명확
- tts.py 호환성 위험: HIGH — scalar_one_or_none + 복수 레코드 조합은 코드에서 직접 확인
- 테스트 gap: HIGH — 기존 테스트 파일 확인, mock 구조 파악

**Research date:** 2026-03-30
**Valid until:** 2026-04-30 (안정적 스택, 30일)
