# Edge-to-Edge WebView 실험 (SafeArea 제거)

> **상태**: 실험 중 (테스트 필요)
> **날짜**: 2026-03-04
> **목적**: Flutter WebView에서 SafeArea 제거 → 웹 CSS가 safe area를 직접 관리하도록 변경. 통화 화면 등에서 상하단 배경색 불일치 문제 해결.

## 변경 내용

### 1. Flutter (`apps/mobile/lib/main.dart`)

- `SafeArea` 위젯 제거 → WebView가 전체 화면 차지
- `SystemUiMode.edgeToEdge` 활성화
- 상태바 + 네비게이션바 투명 처리

### 2. Web viewport (`apps/web/src/app/layout.tsx`)

- `viewportFit: 'cover'` 추가 → OS가 `env(safe-area-inset-*)` 값을 CSS에 전달

### 3. Web CSS (`apps/web/src/app/globals.css`)

- body에 `padding-top: env(safe-area-inset-top, 0px)` 추가
- `.safe-area-top` 유틸리티 클래스 추가

## 이미 적용되어 있던 것 (변경 불필요)

- `bottom-nav.tsx`: `safe-area-bottom` 클래스 사용 중
- `chat-input.tsx`: `safe-area-bottom` 클래스 사용 중
- `voice-input.tsx`: `safe-area-bottom` 클래스 사용 중
- `call-screen.tsx`: `env(safe-area-inset-top)` 직접 사용 중

## 롤백 방법

### 방법 1: git revert (권장)

```bash
# safe-area 실험 커밋 해시 확인
git log --oneline | grep "edge-to-edge"

# 해당 커밋만 되돌리기
git revert <커밋해시>
```

### 방법 2: 수동 롤백

#### `apps/mobile/lib/main.dart`

```dart
// 이 줄 제거:
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

// SystemUiOverlayStyle에서 이 2줄 제거:
systemNavigationBarColor: Colors.transparent,
systemNavigationBarIconBrightness: Brightness.dark,

// WebViewScreen.build()에서 SafeArea 다시 감싸기:
// 변경 전 (현재):
child: Scaffold(
  body: Stack(
    children: [
      WebViewWidget(controller: _controller),
      ...
    ],
  ),
),

// 변경 후 (롤백):
child: Scaffold(
  body: SafeArea(
    child: Stack(
      children: [
        WebViewWidget(controller: _controller),
        ...
      ],
    ),
  ),
),
```

#### `apps/web/src/app/layout.tsx`

```typescript
// viewport에서 이 줄 제거:
viewportFit: 'cover',
```

#### `apps/web/src/app/globals.css`

```css
/* body에서 이 줄 제거: */
padding-top: env(safe-area-inset-top, 0px);

/* 이 유틸리티 클래스 제거 (선택): */
.safe-area-top {
  padding-top: env(safe-area-inset-top, 0px);
}
```

## 테스트 체크리스트

- [ ] iPhone 실기기: 상단 status bar 영역에 콘텐츠 가려지지 않는지
- [ ] iPhone 실기기: 하단 home indicator 영역 정상 처리
- [ ] iPhone 실기기: 통화 화면 배경색 일치 확인
- [ ] Android 에뮬레이터: 상단/하단 시스템 바 영역 정상 표시
- [ ] 웹 브라우저 (PC): 기존 동작에 영향 없는지 확인
- [ ] 로그인 페이지: 상단 여백 정상
- [ ] 하단 네비게이션: 안전 영역 정상 처리
