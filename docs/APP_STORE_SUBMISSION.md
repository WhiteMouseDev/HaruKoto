# 앱 스토어 심사 제출 가이드

> 하루코토(HaruKoto) 앱을 Google Play Store / Apple App Store에 출시하기 위한 전체 과정

---

## 현재 앱 구조

| 항목 | 값 |
|------|-----|
| 앱 이름 | 하루코토 (ハルコト) |
| 패키지명 (Android) | `com.harukoto.app` |
| Bundle ID (iOS) | Runner 프로젝트 설정에서 지정 필요 |
| 프레임워크 | Flutter (WebView 래퍼) → Next.js 웹앱 |
| 웹앱 URL | `https://app.harukoto.co.kr` |
| 버전 | 1.0.0+1 (`pubspec.yaml`) |

---

## Part 1: 개발자 계정 등록

### Google Play Console

| 항목 | 내용 |
|------|------|
| URL | https://play.google.com/console/signup |
| 비용 | **$25 (1회성)** |
| 결제 수단 | 신용/체크카드 |
| 계정 유형 | 개인 또는 조직 (개인 추천 — 조직은 D-U-N-S 번호 필요) |
| 승인 소요 | 결제 즉시 ~ 최대 48시간 |
| 필요 정보 | Google 계정, 본인 인증(신분증), 연락처 |

**등록 절차:**
1. https://play.google.com/console/signup 접속
2. Google 계정으로 로그인
3. 개발자 계약 동의
4. $25 결제
5. **본인 인증** (2023년부터 필수 — 신분증 사진 업로드)
6. 연락처 정보 입력 (이메일, 전화번호)
7. 계정 활성화 대기 (보통 수 시간)

### Apple Developer Program

| 항목 | 내용 |
|------|------|
| URL | https://developer.apple.com/programs/enroll |
| 비용 | **₩129,000/년 (연간 갱신)** |
| 결제 수단 | 신용/체크카드 |
| 계정 유형 | 개인 (추천) 또는 조직 (D-U-N-S 필요) |
| 승인 소요 | 최대 48시간 (보통 24시간 내) |
| 필요 정보 | Apple ID, 본인 인증(신분증), 2단계 인증 활성화 |
| 필수 장비 | **Mac (Xcode 필수)**, iPhone 테스트 기기 권장 |

**등록 절차:**
1. Apple ID 생성 (없으면) + **2단계 인증 활성화** (필수)
2. https://developer.apple.com/programs/enroll 접속
3. 개인 개발자로 등록
4. 본인 인증 (신분증 + Apple 기기에서 확인)
5. ₩129,000 결제
6. 승인 대기 (이메일 확인)

---

## Part 2: 빌드 전 준비사항

### 2-1. 공통 준비물

#### 앱 아이콘
- **1024x1024px PNG** (투명 배경 불가 — 양쪽 스토어 모두)
- 현재: `assets/icon.png` → 해상도 확인 필요
- `flutter_launcher_icons`로 자동 생성 설정 있음

```bash
cd apps/mobile
flutter pub run flutter_launcher_icons
```

#### 스크린샷 (필수)
- **최소 2장**, 권장 4~8장
- 각 디바이스 사이즈별로 필요:

| 플랫폼 | 필요 사이즈 |
|---------|------------|
| Android | 16:9 비율, 최소 320px~최대 3840px |
| iOS - 6.9" | 1320 x 2868px (iPhone 16 Pro Max) |
| iOS - 6.7" | 1290 x 2796px (iPhone 15 Pro Max) |
| iOS - 6.5" | 1284 x 2778px (iPhone 14 Plus) |
| iOS - 5.5" | 1242 x 2208px (iPhone 8 Plus) — 선택 |

**스크린샷 촬영 팁:**
- 시뮬레이터/에뮬레이터에서 촬영
- 주요 화면: 홈, 학습(퀴즈), AI 회화, 마이페이지
- 한국어 UI 그대로 사용 (타겟 시장: 한국)

#### 앱 설명 텍스트
```
[앱 이름]
하루코토 - 일본어 학습

[짧은 설명 (80자 이내)]
매일 한 단어, 봄처럼 피어나는 나의 일본어. JLPT N5~N1 완벽 대비!

[전체 설명 (4000자 이내)]
🌸 하루코토 - 한국인을 위한 일본어 학습 앱

매일 조금씩, 일본어 실력을 키워보세요!

📚 JLPT N5~N1 단어 & 문법
- 레벨별 체계적인 어휘 학습
- 빈칸채우기, 어순배열 등 다양한 퀴즈
- 틀린 문제 복습 기능

🤖 AI 회화 연습
- AI와 실전 일본어 대화
- 음성 통화 & 텍스트 채팅
- 여행, 일상, 비즈니스 등 상황별 시나리오

📊 학습 관리
- 일일 학습 목표 설정
- 연속 학습 스트릭
- 주간 학습 통계

🎌 가나 학습
- 히라가나 & 카타카나 기초부터
- 플래시카드, 매칭 게임

지금 시작하세요! 하루 한 단어로 일본어가 봄처럼 피어납니다 🌸
```

#### 개인정보 처리방침 URL (필수)
- **양쪽 스토어 모두 필수**
- URL 준비 필요 (예: `https://harukoto.co.kr/privacy`)
- 수집 정보: 이메일, 학습 기록, AI 대화 내용 등 명시

#### 카테고리
- **교육 (Education)**

#### 콘텐츠 등급
- **전체이용가** (학습 앱, 폭력/성인 콘텐츠 없음)

---

### 2-2. Android 빌드 준비

#### 서명 키 생성 (Release 빌드용)

현재 `build.gradle`에 `signingConfig = signingConfigs.debug`로 되어 있어 릴리스 서명 설정이 필요합니다.

```bash
# 키스토어 생성
keytool -genkey -v -keystore ~/harukoto-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias harukoto
```

**⚠️ 키스토어 파일과 비밀번호는 절대 잃어버리면 안 됩니다! 백업 필수.**

#### `android/key.properties` 생성

```properties
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=harukoto
storeFile=<키스토어 절대경로>
```

#### `android/app/build.gradle` 수정

```gradle
// signingConfigs 추가
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... 기존 설정

    signingConfigs {
        release {
            keyAlias = keystoreProperties['keyAlias']
            keyPassword = keystoreProperties['keyPassword']
            storeFile = keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword = keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.release
            // ProGuard/R8 난독화 (선택)
            // minifyEnabled true
            // shrinkResources true
        }
    }
}
```

#### AAB 빌드

```bash
cd apps/mobile
flutter build appbundle --release
# 출력: build/app/outputs/bundle/release/app-release.aab
```

---

### 2-3. iOS 빌드 준비

#### Xcode 프로젝트 설정

```bash
cd apps/mobile/ios
pod install  # CocoaPods 의존성 설치
open Runner.xcworkspace  # Xcode에서 열기
```

**Xcode에서 설정할 항목:**
1. **Bundle Identifier**: `com.harukoto.app` (Android와 맞추기)
2. **Team**: Apple Developer 계정 선택
3. **Signing**: Automatically manage signing 체크
4. **Deployment Target**: iOS 15.0 이상 권장
5. **Display Name**: 하루코토

#### Archive & 업로드

```bash
cd apps/mobile
flutter build ipa --release
# 출력: build/ios/ipa/harukoto_mobile.ipa
```

또는 Xcode에서:
1. Product → Archive
2. Distribute App → App Store Connect
3. Upload

---

## Part 3: Google Play Store 제출

### 3-1. Play Console에서 앱 생성

1. [Play Console](https://play.google.com/console) 접속
2. **"앱 만들기"** 클릭
3. 기본 정보 입력:
   - 앱 이름: `하루코토 - 일본어 학습`
   - 기본 언어: 한국어
   - 앱/게임: 앱
   - 유료/무료: 무료 (인앱 결제는 별도)

### 3-2. 스토어 등록정보 작성

| 항목 | 내용 |
|------|------|
| 앱 이름 | 하루코토 - 일본어 학습 |
| 짧은 설명 | 위 텍스트 참조 |
| 전체 설명 | 위 텍스트 참조 |
| 앱 아이콘 | 512x512 PNG |
| 그래픽 이미지 | 1024x500 PNG (프로모션 배너) |
| 스크린샷 | 최소 2장 (16:9) |

### 3-3. 콘텐츠 등급 설문

Play Console → 정책 → 앱 콘텐츠 → **콘텐츠 등급**

설문 응답 기준:
- 폭력: 없음
- 성적 콘텐츠: 없음
- 도박: 없음
- 약물: 없음
- 사용자 생성 콘텐츠: **있음** (AI 대화)
- 위치 정보: 없음

→ 결과: 대부분 **전체이용가 (PEGI 3 / Everyone)**

### 3-4. 앱 콘텐츠 설정 (필수 체크리스트)

| 항목 | 하루코토 해당 여부 | 설정 |
|------|------------------|------|
| 개인정보 처리방침 | ✅ | URL 입력 |
| 광고 포함 | ❌ (현재 없음) | "광고 미포함" |
| 앱 접근 권한 | ✅ (로그인 필요) | 테스트 계정 정보 제공 |
| 타겟 연령층 | 전체 | 13세 이상 |
| 뉴스 앱 | ❌ | 해당 없음 |
| 코로나19 앱 | ❌ | 해당 없음 |
| 데이터 보안 | ✅ | 아래 참조 |

#### 데이터 보안 섹션

| 데이터 유형 | 수집 여부 | 용도 |
|-------------|----------|------|
| 이메일 | ✅ | 계정 관리 |
| 이름/닉네임 | ✅ | 앱 개인화 |
| 학습 활동 | ✅ | 앱 기능 (진도 추적) |
| 채팅 메시지 | ✅ | AI 대화 기능 |
| 결제 정보 | ✅ | 구독 결제 (PortOne 통해) |
| 기기 식별자 | ❌ | |
| 위치 | ❌ | |

### 3-5. 테스트 트랙 (권장)

**바로 프로덕션 출시하지 말고, 내부 테스트부터:**

1. **내부 테스트** (Internal Testing)
   - 최대 100명 테스터
   - 심사 없이 바로 배포
   - AAB 업로드 → 링크 생성 → 테스터에게 공유

2. **비공개 테스트** (Closed Testing)
   - 이메일로 테스터 초대
   - 간단한 심사 (1~3일)

3. **공개 테스트** (Open Testing)
   - 누구나 참여 가능
   - 정식 심사와 동일

4. **프로덕션** (Production)
   - 정식 출시
   - 심사 소요: **보통 1~3일, 최대 7일**

### 3-6. AAB 업로드

1. Play Console → 프로덕션 (또는 테스트 트랙)
2. "새 버전 만들기"
3. `app-release.aab` 업로드
4. 버전 이름/코드 확인
5. 출시 노트 작성:

```
🌸 하루코토 v1.0.0 첫 출시!

• JLPT N5~N1 단어 & 문법 학습
• AI 음성/텍스트 회화 연습
• 가나(히라가나/카타카나) 학습
• 일일 학습 목표 & 스트릭
• 주간 학습 통계
```

6. "검토를 위해 제출"

---

## Part 4: Apple App Store 제출

### 4-1. App Store Connect에서 앱 생성

1. [App Store Connect](https://appstoreconnect.apple.com) 접속
2. "내 앱" → "+" → "새 앱"
3. 기본 정보:
   - 플랫폼: iOS
   - 이름: `하루코토 - 일본어 학습`
   - 기본 언어: 한국어
   - 번들 ID: `com.harukoto.app`
   - SKU: `harukoto-app`

### 4-2. 앱 정보 작성

| 항목 | 내용 |
|------|------|
| 부제목 | 매일 한 단어, 봄처럼 피어나는 일본어 |
| 카테고리 | 교육 |
| 콘텐츠 등급 | 4+ (학습 앱) |
| 개인정보 처리방침 URL | `https://harukoto.co.kr/privacy` |
| 앱 설명 | 위 텍스트 참조 |
| 키워드 | 일본어,JLPT,학습,단어,문법,회화,AI,N5,N2,가나 |
| 지원 URL | `https://harukoto.co.kr` |

### 4-3. 스크린샷 업로드

**필수 디바이스 사이즈:**

| 디바이스 | 사이즈 | 필수 |
|----------|--------|------|
| iPhone 6.9" | 1320 x 2868 | ✅ (또는 6.7") |
| iPhone 6.7" | 1290 x 2796 | ✅ |
| iPhone 6.5" | 1284 x 2778 | ✅ |
| iPhone 5.5" | 1242 x 2208 | 선택 |
| iPad Pro 13" | 2064 x 2752 | iPad 지원 시 필수 |

### 4-4. 앱 심사 정보

#### 로그인 필요 앱 — 테스트 계정 제공 (필수!)

```
계정: test@harukoto.co.kr
비밀번호: TestReview2024!
```

**⚠️ 심사관이 로그인하여 모든 기능을 테스트할 수 있어야 합니다.**
- 테스트 계정에 학습 데이터가 있어야 함
- 결제 기능은 Sandbox 환경으로 테스트 가능해야 함

#### 심사 메모 (Review Notes)

```
이 앱은 한국인을 위한 일본어 학습 앱입니다.

[로그인 방법]
- 이메일/비밀번호 또는 Google 로그인

[주요 기능]
1. 홈: 학습 진도, 스트릭, 일일 미션
2. 학습: JLPT 레벨별 단어/문법 퀴즈
3. AI 회화: AI와 일본어 대화 (음성/텍스트)
4. 통계: 학습 기록 및 달력
5. 마이페이지: 프로필, 설정, 구독

[인앱 결제]
- 프리미엄 구독 (월간/연간)
- PortOne (한국 PG) 연동

[마이크 사용]
- AI 음성 통화 시에만 마이크 사용 (NSMicrophoneUsageDescription 설정 완료)

[테스트 계정]
- 위에 제공한 계정으로 로그인하여 모든 기능을 테스트하실 수 있습니다.
```

### 4-5. 빌드 업로드

**방법 1: Xcode에서 직접**
1. Xcode → Product → Archive
2. Distribute App → App Store Connect
3. Upload

**방법 2: CLI**
```bash
flutter build ipa --release
# Transporter 앱으로 업로드하거나:
xcrun altool --upload-app -f build/ios/ipa/*.ipa \
  -t ios -u <Apple ID> -p <앱 전용 비밀번호>
```

### 4-6. 심사 제출

1. App Store Connect → 빌드 선택
2. 모든 정보 입력 확인
3. "심사를 위해 제출"
4. 심사 소요: **보통 24~48시간, 최대 7일**

---

## Part 5: WebView 앱 심사 리젝 대비

### ⚠️ WebView 래퍼 앱의 심사 리스크

**Apple은 WebView 래퍼 앱에 대해 엄격합니다.** 단순히 웹사이트를 감싼 앱은 리젝될 수 있습니다.

#### Apple 가이드라인 4.2 — Minimum Functionality

> "Your app should include features, content, and UI that elevate it beyond a repackaged website."

#### 리젝 방지를 위한 네이티브 기능 체크리스트

| 기능 | 현재 상태 | 심사 통과 기여도 |
|------|----------|-----------------|
| 네이티브 스플래시 스크린 | ✅ 있음 | ★★☆ |
| Google 로그인 (네이티브) | ✅ 있음 | ★★★ |
| 마이크 접근 (음성 통화) | ✅ 있음 | ★★★ |
| 푸시 알림 | ⚠️ SW 기반 (웹) | ★★★ |
| 오프라인 지원 | ⚠️ SW 캐싱만 | ★★☆ |
| 결제 (한국 PG) | ✅ 있음 | ★★☆ |

#### 권장 추가 작업 (리젝 방지)

1. **푸시 알림 네이티브 구현** — Firebase Cloud Messaging (FCM) + APNs
   - 웹 Push 대신 네이티브 Push 사용
   - "오늘 학습 알림" 등 학습 리마인더
   - 심사관에게 "네이티브 기능"으로 어필 가능

2. **오프라인 대응 UI** — 네트워크 없을 때 Flutter 네이티브 화면
   ```
   "인터넷 연결이 필요합니다" + 재시도 버튼
   ```

3. **앱 전용 기능 강조** — 심사 메모에 네이티브 기능 명시
   - "네이티브 마이크 접근으로 AI 음성 통화 지원"
   - "네이티브 Google Sign-In 통합"
   - "네이티브 결제 연동 (한국 PG)"

### Google Play는 상대적으로 관대

Google Play는 WebView 앱에 대해 Apple만큼 엄격하지 않습니다. 하지만:
- **앱 콘텐츠 정책** 준수 필수
- **데이터 보안 섹션** 정확히 작성
- **테스트 계정** 제공

---

## Part 6: 인앱 결제 관련

### 현재 결제 구조

하루코토는 **PortOne (한국 PG)**을 통해 결제하고 있습니다.

### Apple의 인앱 결제 정책

> **디지털 콘텐츠/구독은 반드시 Apple IAP를 사용해야 합니다.**

| 결제 유형 | Apple IAP 필수? |
|----------|----------------|
| 프리미엄 구독 (학습 콘텐츠) | ✅ **필수** |
| AI 통화 크레딧 | ✅ **필수** |
| 실물 상품/서비스 | ❌ 외부 결제 가능 |

**⚠️ 현재 PortOne 결제만으로는 Apple 심사를 통과할 수 없습니다.**

#### 선택지

| 옵션 | 설명 | 권장 |
|------|------|------|
| A. Apple IAP 구현 | StoreKit 2 + 서버 검증 | 정석이지만 개발 비용 큼 |
| B. 웹에서만 결제 유도 | 앱 내 결제 버튼 제거, 웹에서 구독 | Apple 정책 위반 가능성 |
| C. 일단 무료 기능만 출시 | 결제 기능 없이 먼저 출시 | ✅ **가장 현실적** |

**권장: 옵션 C**
1. 먼저 무료 기능만으로 심사 통과
2. 이후 Apple IAP / Google Play Billing 추가

### Google Play Billing

Google도 디지털 콘텐츠에 대해 Google Play Billing을 요구하지만, 한국에서는 **제3자 결제 허용** (전기통신사업법)으로 PortOne 결제도 가능할 수 있습니다. 다만 명시적인 선택 UI가 필요합니다.

---

## Part 7: 전체 체크리스트

### 계정 등록
- [ ] Google Play Console 가입 ($25)
- [ ] Apple Developer Program 가입 (₩129,000/년)

### 앱 준비
- [ ] 앱 아이콘 1024x1024 PNG 준비
- [ ] 스크린샷 촬영 (각 디바이스 사이즈별)
- [ ] 그래픽 이미지 1024x500 (Google Play용)
- [ ] 앱 설명 텍스트 작성
- [ ] 개인정보 처리방침 페이지 작성 & 배포
- [ ] 테스트 계정 준비

### Android 빌드
- [ ] Release 서명 키 생성
- [ ] `key.properties` 설정
- [ ] `build.gradle` 서명 설정 수정
- [ ] `flutter build appbundle --release`
- [ ] 내부 테스트 트랙에 먼저 업로드

### iOS 빌드
- [ ] Bundle Identifier 설정 (`com.harukoto.app`)
- [ ] Apple Developer 계정 Signing 설정
- [ ] `flutter build ipa --release`
- [ ] Xcode → Archive → Upload to App Store Connect

### 스토어 설정
- [ ] Google Play Console — 앱 콘텐츠(데이터 보안, 등급) 작성
- [ ] App Store Connect — 앱 정보, 심사 메모 작성
- [ ] 양쪽 모두 테스트 계정 정보 입력

### 심사 제출
- [ ] Google Play: 내부 테스트 → 비공개 → 프로덕션
- [ ] Apple: TestFlight 테스트 → App Store 제출

### 결제 (후순위)
- [ ] Apple IAP (StoreKit 2) 구현 검토
- [ ] Google Play Billing 구현 검토

---

## 예상 비용 요약

| 항목 | 비용 | 비고 |
|------|------|------|
| Google Play Console | $25 (1회) | 약 ₩34,000 |
| Apple Developer Program | ₩129,000/년 | 매년 갱신 |
| **합계 (첫 해)** | **약 ₩163,000** | |

---

## 예상 소요 기간

| 단계 | 소요 기간 |
|------|----------|
| 개발자 계정 등록 | 1~2일 |
| 빌드 준비 (서명, 설정) | 1일 |
| 스크린샷 & 설명 작성 | 1~2일 |
| 개인정보 처리방침 작성 | 1일 |
| Google Play 심사 | 1~7일 |
| Apple App Store 심사 | 1~7일 |
| **총 예상** | **약 1~2주** |

---

## 참고 링크

- [Google Play Console 도움말](https://support.google.com/googleplay/android-developer)
- [Apple App Store 심사 가이드라인](https://developer.apple.com/app-store/review/guidelines/)
- [Flutter 배포 가이드 (Android)](https://docs.flutter.dev/deployment/android)
- [Flutter 배포 가이드 (iOS)](https://docs.flutter.dev/deployment/ios)
- [Apple IAP 구현 가이드](https://developer.apple.com/in-app-purchase/)
