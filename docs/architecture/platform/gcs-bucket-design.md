# GCS 버킷 설계서

## 버킷 개요

- **버킷명**: `harukoto-storage`
- **리전**: `asia-northeast3` (서울)
- **스토리지 클래스**: Standard
- **접근 제어**: Uniform bucket-level access

---

## 폴더 구조

```
harukoto-storage/
│
├── avatars/                          # 유저 프로필 사진
│   └── {userId}.webp                 # 유저당 1장, 덮어쓰기
│
├── characters/                       # AI 캐릭터 아바타 (관리자 업로드)
│   ├── haru-avatar.png
│   ├── sora-avatar.png
│   ├── yuki-avatar.png
│   ├── kaito-avatar.png
│   ├── mio-avatar.png
│   ├── riku-avatar.png
│   ├── ren-avatar.png
│   └── aoi-avatar.png
│
├── logos/                            # 브랜드 로고 에셋
│   ├── logo-horizontal.svg
│   ├── logo-vertical.svg
│   ├── logo-symbol.svg
│   └── logo-wordmark.svg
│
├── tts/                              # 단어/가나 발음 파일 (배치 생성)
│   ├── vocab/
│   │   ├── N5/{vocabId}.mp3
│   │   ├── N4/{vocabId}.mp3
│   │   ├── N3/{vocabId}.mp3
│   │   ├── N2/{vocabId}.mp3
│   │   └── N1/{vocabId}.mp3
│   ├── vocab-example/                # 예문 발음
│   │   ├── N5/{vocabId}.mp3
│   │   └── ...
│   └── kana/
│       ├── hiragana/{kanaId}.mp3
│       └── katakana/{kanaId}.mp3
│
└── recordings/                       # [추후] 유저 음성 녹음
    └── {userId}/{conversationId}/{timestamp}.webm
```

---

## 접근 제어 정책

| 폴더 | 읽기 | 쓰기 | 방식 |
|------|------|------|------|
| `avatars/` | Public (CDN) | Signed URL (인증된 유저) | 본인 userId만 업로드 가능 |
| `characters/` | Public (CDN) | 관리자만 | 배포/시딩 시 업로드 |
| `logos/` | Public (CDN) | 관리자만 | 거의 변경 없음 |
| `tts/` | Public (CDN) | 배치 스크립트 | 서비스 계정으로 업로드 |
| `recordings/` | Signed URL (본인만) | Signed URL (인증된 유저) | 본인 데이터만 접근 |

---

## 파일 규격

### 프로필 사진 (`avatars/`)
- **포맷**: WebP (서버에서 변환)
- **최대 업로드 크기**: 2MB (원본 기준)
- **저장 크기**: 200x200px, 리사이즈 후 저장
- **파일명**: `{userId}.webp` (덮어쓰기로 구버전 자동 정리)
- **Content-Type**: `image/webp`
- **Cache-Control**: `public, max-age=3600` (1시간, 변경 가능성 있음)

### AI 캐릭터 아바타 (`characters/`)
- **포맷**: PNG
- **크기**: 512x512px 권장
- **Cache-Control**: `public, max-age=604800` (7일, 거의 안 바뀜)

### 로고 (`logos/`)
- **포맷**: SVG
- **Cache-Control**: `public, max-age=2592000` (30일)

### TTS 발음 파일 (`tts/`)
- **포맷**: MP3 (128kbps)
- **예상 파일 수**: 어휘 7,681 × 2(단어+예문) + 가나 208 = ~15,570개
- **예상 총 용량**: ~500MB (파일당 평균 30KB)
- **Cache-Control**: `public, max-age=2592000` (30일, immutable)

### 음성 녹음 (`recordings/`) — 추후 도입
- **포맷**: WebM (브라우저 MediaRecorder 기본)
- **최대 길이**: 10분
- **보존 기간**: 90일 후 자동 삭제 (Lifecycle Rule)

---

## 유저 탈퇴 시 데이터 처리

### 즉시 삭제 대상
| 데이터 | 경로 | 삭제 방식 |
|--------|------|----------|
| 프로필 사진 | `avatars/{userId}.webp` | API에서 직접 삭제 |
| 음성 녹음 | `recordings/{userId}/` | 폴더 전체 삭제 (prefix 삭제) |

### 삭제 불필요
| 데이터 | 이유 |
|--------|------|
| AI 캐릭터 아바타 | 공용 에셋, 유저 데이터 아님 |
| 로고 | 공용 에셋 |
| TTS 발음 파일 | 공용 에셋, 유저 데이터 아님 |

### 탈퇴 처리 플로우

```
유저 탈퇴 요청
  ├─ 1. DB 유저 데이터 삭제/익명화 (Prisma cascade)
  ├─ 2. GCS 파일 삭제
  │   ├─ avatars/{userId}.webp 삭제
  │   └─ recordings/{userId}/ 전체 삭제
  ├─ 3. Supabase Auth 유저 삭제
  └─ 4. 완료 응답
```

### 실패 안전장치
- GCS 삭제 실패 시에도 탈퇴는 진행 (유저 경험 우선)
- 삭제 실패 건은 로그 기록 → 주기적 정리 배치로 처리
- `recordings/` 폴더는 Lifecycle Rule(90일)이 있어 최종 안전망 역할

---

## Lifecycle Rules (버킷 설정)

| 규칙 | 대상 | 조건 | 액션 |
|------|------|------|------|
| 녹음 자동 삭제 | `recordings/` | 90일 경과 | Delete |
| 오래된 아바타 정리 | `avatars/` | 비활성 유저 (365일 미접속) | 추후 배치로 처리 |

---

## 구현 우선순위

### Phase 1: 기본 인프라 + 프로필 사진
1. GCS 버킷 생성 및 CORS/IAM 설정
2. `@google-cloud/storage` 패키지 추가
3. 프로필 사진 업로드 API (`POST /api/v1/user/avatar`)
4. 마이페이지 프로필 사진 업로드 UI

### Phase 2: 기존 에셋 마이그레이션
1. AI 캐릭터 아바타를 GCS로 이동
2. 로고 에셋을 GCS로 이동
3. DB `AiCharacter.avatarUrl` 업데이트
4. `public/images/` 정리

### Phase 3: TTS 발음 파일
1. 발음 파일 배치 생성 스크립트 작성
2. GCS 업로드
3. DB `Vocabulary.audioUrl`, `KanaCharacter.audioUrl` 업데이트
4. 클라이언트에서 GCS URL로 재생

### Phase 4: 음성 녹음 (추후)
1. 녹음 저장 API
2. 녹음 재생 UI
3. Lifecycle Rule 설정
4. 탈퇴 시 삭제 로직

---

## 환경 변수

```env
# GCS
GCS_BUCKET_NAME=harukoto-storage
GCS_PROJECT_ID=harukoto-project
GOOGLE_APPLICATION_CREDENTIALS=./credentials/gcs-service-account.json

# Public URL (CDN)
NEXT_PUBLIC_GCS_CDN_URL=https://storage.googleapis.com/harukoto-storage
```

---

## 참고: 번들에 유지하는 에셋

다음은 GCS로 옮기지 않고 `/public/`에 유지:
- `/sounds/correct.mp3` — 퀴즈 효과음 (41KB, 즉시 재생 필요)
- `/sounds/incorrect.mp3` — 퀴즈 효과음 (40KB)
- `/sounds/complete.mp3` — 완료 효과음 (66KB)
- `/sounds/ringtone.wav` — 통화 벨소리 (35KB)
- `/images/fox.svg` — 마스코트 SVG (컴포넌트에서 직접 참조)
- `/images/fox_charactor.svg` — 마스코트 변형

> 이유: 용량이 작고(총 ~230KB), 변경이 거의 없으며, 네트워크 지연 없이 즉시 재생/표시가 필요
