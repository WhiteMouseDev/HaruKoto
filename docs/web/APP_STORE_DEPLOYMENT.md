# 하루코토 앱 스토어 배포 가이드

## 앱 정보 요약

| 항목 | 값 |
|------|-----|
| 앱 이름 | 하루코토 |
| Android 패키지명 | `com.harukoto.app` |
| iOS Bundle ID | `com.harukoto.harukotoMobile` |
| 현재 버전 | 1.0.0+1 |
| Flutter 프로젝트 경로 | `apps/mobile` |
| Apple Team ID | `2V69564W25` |

---

## Part 1: Google Play Store 배포

### 1.1 사전 준비

#### Google Play Console 계정 생성
1. https://play.google.com/console 접속
2. Google 계정으로 로그인
3. 개발자 등록비 **$25 (일회성)** 결제
4. 개발자 프로필 정보 입력 (이름, 이메일, 전화번호, 주소)
5. 본인 인증 완료 (계정 승인까지 최대 48시간 소요)

#### 앱 서명 키 생성
릴리즈 빌드에는 프로덕션 서명 키가 필요합니다.

```bash
# 키스토어 생성
keytool -genkey -v -keystore ~/harukoto-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias harukoto

# 입력 항목:
# - 키스토어 비밀번호 (기억해둘 것)
# - 이름, 조직, 도시, 국가코드(KR)
```

> **중요**: `harukoto-release-key.jks` 파일과 비밀번호를 안전하게 보관하세요. 분실 시 앱 업데이트가 불가합니다.

#### 서명 설정 파일 생성

`apps/mobile/android/key.properties` 파일 생성:
```properties
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=harukoto
storeFile=<키스토어 절대경로, 예: /Users/kimkunwoo/harukoto-release-key.jks>
```

> **주의**: `key.properties`는 `.gitignore`에 추가하여 절대 커밋하지 마세요.

#### build.gradle 서명 설정

`apps/mobile/android/app/build.gradle` 수정:

```gradle
// android {} 블록 위에 추가
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // 기존 내용...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 1.2 릴리즈 빌드

```bash
cd apps/mobile

# 의존성 설치
flutter pub get

# App Bundle 빌드 (Play Store는 AAB 형식 필수)
flutter build appbundle --release

# 빌드 결과물 위치:
# build/app/outputs/bundle/release/app-release.aab
```

### 1.3 Play Console에서 앱 등록

#### 앱 생성
1. [Play Console](https://play.google.com/console) → **앱 만들기**
2. 입력 항목:
   - **앱 이름**: 하루코토 - 일본어 학습
   - **기본 언어**: 한국어 (ko-KR)
   - **앱 또는 게임**: 앱
   - **유료 또는 무료**: 무료
   - 개발자 프로그램 정책 동의 체크

#### 스토어 등록정보 작성

**기본 정보**:
- **앱 이름**: 하루코토 - 일본어 학습
- **간단한 설명** (80자 이내):
  > JLPT 대비 + AI 회화 연습. 하루 한 마디로 시작하는 일본어 학습 앱
- **자세한 설명** (4000자 이내):
  > 하루코토는 한국인을 위한 일본어 학습 앱입니다.
  >
  > 주요 기능:
  > - JLPT N5~N1 단계별 단어/문법 학습
  > - AI와 실시간 일본어 회화 연습
  > - 히라가나/가타카나 학습
  > - 퀴즈로 복습하기
  > - 학습 통계 및 연속 학습 기록
  > - 틀린 문제 복습
  >
  > 프리미엄 기능:
  > - 무제한 AI 채팅 및 통화
  > - 고급 학습 분석

**그래픽 에셋** (필수):
| 에셋 | 규격 | 설명 |
|------|------|------|
| 앱 아이콘 | 512 x 512px (PNG, 32bit) | 투명 배경 불가 |
| 대표 이미지 | 1024 x 500px | 스토어 상단 배너 |
| 스크린샷 (휴대폰) | 최소 2장, 16:9 또는 9:16 | 앱 화면 캡처 |
| 스크린샷 (태블릿) | 최소 1장 (7인치, 10인치 각각) | 선택사항 |

> 스크린샷은 실제 앱 화면을 캡처하거나 [Figma 목업 템플릿](https://www.figma.com/community)으로 제작

#### 앱 카테고리 및 태그
- **카테고리**: 교육
- **태그**: 일본어, 학습, JLPT, 언어, AI

#### 콘텐츠 등급
1. **앱 콘텐츠** → **콘텐츠 등급** → 설문지 시작
2. 카테고리: **유틸리티, 생산성, 커뮤니케이션 또는 기타**
3. 폭력성/성적 콘텐츠 등 모두 **아니오** 선택
4. 예상 등급: **전체이용가 (IARC 3+)**

#### 개인정보처리방침
- **개인정보처리방침 URL** 필수 입력
- 예: `https://app.harukoto.co.kr/privacy`
- 이미 앱 내 개인정보처리방침 페이지가 있다면 해당 URL 사용

#### 데이터 보안
Play Console → **앱 콘텐츠** → **데이터 보안** 섹션:

수집하는 데이터 유형 체크:
- [x] 이메일 주소 (계정 관리)
- [x] 구매 내역 (인앱 결제)
- [x] 앱 활동 (학습 기록)
- [ ] 위치 (수집 안 함)
- [ ] 전화번호 (수집 안 함)

### 1.4 테스트 트랙 배포

> 바로 프로덕션에 올리지 말고 내부 테스트부터 진행하세요.

#### 내부 테스트 (Internal Testing)
1. **테스트** → **내부 테스트** → **새 버전 만들기**
2. `app-release.aab` 업로드
3. **테스터** 탭에서 테스트 이메일 추가
4. **버전 검토 시작**
5. 테스트 링크가 생성됨 → 테스터에게 공유

#### 비공개 테스트 (Closed Testing)
- 내부 테스트 통과 후 진행
- 최소 **20명의 테스터**가 **14일 이상** 테스트해야 프로덕션 출시 가능 (신규 개발자 계정)

#### 프로덕션 출시
1. **프로덕션** → **새 버전 만들기**
2. AAB 업로드
3. 출시 노트 작성 (한국어)
4. **프로덕션에 출시 시작**
5. Google 심사 (보통 1~7일, 첫 출시는 더 걸릴 수 있음)

### 1.5 인앱 결제 설정 (포트원 사용 시)

현재 포트원(PortOne) 경유 웹 결제 방식을 사용하므로 Google Play 인앱 결제를 사용하지 않습니다.

> **주의**: Google Play 정책상 앱 내 디지털 콘텐츠 판매 시 Google Play 결제 시스템을 사용해야 할 수 있습니다. 현재 WebView 기반 결제 방식이 정책에 부합하는지 확인이 필요합니다. 거절될 경우 Google Play Billing Library 연동이 필요할 수 있습니다.

---

## Part 2: Apple App Store 배포

### 2.1 사전 준비

#### Apple Developer Program 등록
1. https://developer.apple.com/programs/ 접속
2. Apple ID로 로그인
3. 개발자 등록비 **₩129,000/년 (연간 갱신)** 결제
4. 개인 또는 조직으로 등록
   - **개인**: 본인 확인 (신분증)
   - **조직**: D-U-N-S 번호 필요 (무료 발급, 2~4주 소요)
5. 계정 승인 대기 (보통 24~48시간)

#### 인증서 및 프로비저닝 프로파일 설정

**Xcode에서 자동 서명 (권장)**:
1. Xcode에서 `apps/mobile/ios/Runner.xcworkspace` 열기
2. Runner 타겟 → **Signing & Capabilities**
3. **Team**: Apple Developer 계정 선택 (2V69564W25)
4. **Automatically manage signing** 체크
5. Bundle Identifier 확인: `com.harukoto.harukotoMobile`

> **Bundle ID 참고**: 현재 `com.harukoto.harukotoMobile`로 설정되어 있습니다. 필요 시 `com.harukoto.app`으로 통일할 수 있으나, 한 번 App Store에 등록하면 변경 불가합니다.

### 2.2 App Store Connect 설정

#### 앱 등록
1. https://appstoreconnect.apple.com 접속
2. **나의 앱** → **+** → **신규 앱**
3. 입력 항목:
   - **플랫폼**: iOS
   - **이름**: 하루코토 - 일본어 학습
   - **기본 언어**: 한국어
   - **번들 ID**: `com.harukoto.harukotoMobile` (Xcode에서 등록한 것)
   - **SKU**: `harukoto-ios-001` (내부 관리용, 고유값)

#### 앱 정보 입력

**앱 스토어 탭**:

| 항목 | 내용 |
|------|------|
| 부제 | AI와 함께하는 일본어 학습 |
| 카테고리 | 교육 |
| 보조 카테고리 | 참고 (Reference) |
| 콘텐츠 등급 | 4+ (연령 제한 없음) |
| 라이선스 계약 | 표준 Apple EULA 사용 |

**버전 정보**:
- **홍보 문구** (170자):
  > JLPT 대비부터 AI 실전 회화까지, 하루 한 마디로 시작하는 일본어
- **설명**:
  > (Google Play와 동일한 내용 사용)
- **키워드** (100자, 쉼표 구분):
  > 일본어,JLPT,학습,회화,AI,단어,문법,히라가나,가타카나,일본
- **지원 URL**: `https://app.harukoto.co.kr`
- **개인정보처리방침 URL**: `https://app.harukoto.co.kr/privacy`

**스크린샷** (필수):

| 기기 | 규격 | 필수 |
|------|------|------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796px | 필수 |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688px | 필수 |
| iPhone 5.5" (8 Plus) | 1242 x 2208px | 선택 |
| iPad Pro 12.9" (6세대) | 2048 x 2732px | iPad 지원 시 필수 |

> 각 기기별 최소 1장, 최대 10장. 실제 앱 화면 또는 목업 사용.

**앱 아이콘**:
- 1024 x 1024px (PNG, 투명 배경 불가, 둥근 모서리 X — Apple이 자동 처리)

### 2.3 릴리즈 빌드 및 업로드

#### 빌드

```bash
cd apps/mobile

# 의존성 설치
flutter pub get

# iOS Pod 설치
cd ios && pod install && cd ..

# 릴리즈 빌드
flutter build ios --release

# 또는 Xcode에서 직접 빌드:
# Xcode → Product → Archive
```

#### Xcode에서 Archive 및 업로드

1. Xcode에서 `Runner.xcworkspace` 열기
2. 상단 디바이스를 **Any iOS Device (arm64)** 선택
3. **Product** → **Archive**
4. Archive 완료 후 **Distribute App** 클릭
5. **App Store Connect** 선택 → **Upload**
6. 옵션 확인:
   - [x] Upload your app's symbols (권장)
   - [x] Manage Version and Build Number
7. **Upload** 클릭

> 또는 CLI로 업로드:
> ```bash
> xcrun altool --upload-app --type ios \
>   --file build/ios/ipa/*.ipa \
>   --apiKey <API_KEY> --apiIssuer <ISSUER_ID>
> ```

### 2.4 앱 심사 제출

#### 심사 정보

| 항목 | 내용 |
|------|------|
| 로그인 필요 여부 | 예 (테스트 계정 제공 필요) |
| 테스트 계정 이메일 | 심사용 테스트 계정 이메일 |
| 테스트 계정 비밀번호 | 심사용 테스트 계정 비밀번호 |
| 연락처 이름 | 본인 이름 |
| 연락처 전화번호 | 본인 번호 |
| 연락처 이메일 | whitemousedev@gmail.com |
| 심사 메모 | (선택) 앱 사용법 안내 |

> **중요**: Apple 심사팀이 로그인하여 앱을 테스트합니다. 반드시 동작하는 테스트 계정을 준비하세요.

#### 수출 규정 준수
- **암호화 사용 여부**: 예 (HTTPS 사용)
- **면제 대상**: 예 (표준 HTTPS/TLS만 사용하므로 면제)

#### 앱 추적 투명성 (ATT)
- 현재 광고 추적을 하지 않으므로 ATT 팝업 불필요
- App Store Connect에서 **추적하지 않음**으로 설정

#### 제출
1. 빌드가 App Store Connect에 표시되면 (보통 5~30분 소요) 버전에 빌드 추가
2. 모든 필수 항목 입력 확인
3. **심사를 위해 제출** 클릭
4. 심사 소요 시간: 보통 **24~48시간** (첫 제출은 더 걸릴 수 있음)

### 2.5 Apple 심사 주의사항

WebView 기반 앱은 Apple 심사에서 거절될 수 있습니다. 대비 사항:

#### 거절 사유 및 대응

| 거절 사유 | 대응 방법 |
|-----------|-----------|
| **4.2 Minimum Functionality** — 웹사이트를 단순히 감싼 앱 | 네이티브 기능 강조 (마이크/AI 통화, 푸시 알림, 오프라인 학습) |
| **3.1.1 In-App Purchase** — 앱 내 디지털 콘텐츠 구매 시 IAP 필수 | 포트원 결제 대신 Apple IAP 연동 필요할 수 있음 |
| **5.1.1 Data Collection** — 개인정보 수집 관련 | 개인정보처리방침 페이지 필수, 앱 추적 투명성 설정 |
| **2.1 Performance** — 앱이 제대로 동작하지 않음 | 심사 전 모든 기능 테스트 완료 |

> **인앱 결제 관련**: Apple은 앱 내 디지털 콘텐츠/구독에 대해 **Apple IAP 사용을 강제**합니다. 현재 포트원 웹 결제 방식은 심사에서 거절될 가능성이 높습니다. App Store 배포 시에는 StoreKit 2 연동을 고려해야 합니다.

---

## Part 3: 버전 관리

### 버전 번호 규칙

`pubspec.yaml`의 `version` 필드: `major.minor.patch+buildNumber`

```yaml
# 예시
version: 1.0.0+1    # 첫 출시
version: 1.0.1+2    # 버그 수정
version: 1.1.0+3    # 기능 추가
version: 2.0.0+4    # 대규모 업데이트
```

- **major.minor.patch**: 사용자에게 보이는 버전 (versionName)
- **buildNumber**: 스토어 내부 버전 (항상 증가해야 함)
- Android: `versionCode` = buildNumber, `versionName` = major.minor.patch
- iOS: `CFBundleVersion` = buildNumber, `CFBundleShortVersionString` = major.minor.patch

### 업데이트 배포 시

```bash
# pubspec.yaml 버전 업데이트 후

# Android
flutter build appbundle --release
# → Play Console에 새 버전 업로드

# iOS
flutter build ios --release
# → Xcode Archive → App Store Connect 업로드
```

---

## Part 4: 체크리스트

### 배포 전 공통 체크리스트

- [ ] 앱 아이콘 준비 (512x512 Android, 1024x1024 iOS)
- [ ] 스토어 스크린샷 준비 (각 기기별)
- [ ] 개인정보처리방침 페이지 URL 확인
- [ ] 이용약관 페이지 URL 확인
- [ ] 앱 설명, 키워드 작성
- [ ] 테스트 계정 준비 (Apple 심사용)
- [ ] 모든 기능 테스트 완료
- [ ] 크래시 없음 확인

### Google Play 체크리스트

- [ ] Google Play Console 개발자 계정 생성 ($25)
- [ ] 서명 키(JKS) 생성 및 안전 보관
- [ ] `key.properties` 설정
- [ ] `build.gradle` 서명 설정
- [ ] AAB 빌드 성공
- [ ] 내부 테스트 배포 및 확인
- [ ] 콘텐츠 등급 설문 완료
- [ ] 데이터 보안 섹션 완료
- [ ] 스토어 등록정보 모두 입력
- [ ] 비공개 테스트 20명 14일 (신규 개발자)

### App Store 체크리스트

- [ ] Apple Developer Program 등록 (₩129,000/년)
- [ ] Xcode 서명 설정 완료
- [ ] App Store Connect에 앱 등록
- [ ] 스크린샷 (6.7", 6.5" 필수)
- [ ] Archive 및 업로드 성공
- [ ] 심사 정보 입력 (테스트 계정 포함)
- [ ] 수출 규정 준수 설정
- [ ] 인앱 결제 정책 확인 (IAP vs 포트원)

---

## Part 5: 참고 링크

| 항목 | URL |
|------|-----|
| Google Play Console | https://play.google.com/console |
| App Store Connect | https://appstoreconnect.apple.com |
| Apple Developer | https://developer.apple.com |
| Flutter 배포 가이드 (Android) | https://docs.flutter.dev/deployment/android |
| Flutter 배포 가이드 (iOS) | https://docs.flutter.dev/deployment/ios |
| 앱 아이콘 생성기 | https://www.appicon.co |
| 스크린샷 목업 생성기 | https://mockuphone.com |
