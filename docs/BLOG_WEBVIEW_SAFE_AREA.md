# Flutter WebView에서 SafeArea 배경색 문제 해결하기

> Flutter WebView 앱에서 SafeArea 영역과 웹 콘텐츠의 배경색이 불일치하는 문제를 해결한 과정을 정리합니다.

## 문제 상황

Flutter WebView로 감싼 웹앱에서 **AI 음성 통화 화면**(어두운 배경)에 진입하면, SafeArea 영역(상단 status bar, 하단 home indicator)은 여전히 밝은 Scaffold 배경색을 보여줍니다.

```
┌─────────────────────┐
│  ░░░ 밝은 영역 ░░░  │  ← SafeArea (status bar)
├─────────────────────┤
│                     │
│   어두운 통화 화면   │  ← WebView 콘텐츠
│                     │
├─────────────────────┤
│  ░░░ 밝은 영역 ░░░  │  ← SafeArea (home indicator)
└─────────────────────┘
```

**스크린샷**: (통화 화면에서 상하단 밝은 영역이 보이는 스크린샷 첨부)

---

## 실험 1: CSS SafeArea 방식 (실패)

### 접근법

Flutter의 `SafeArea` 위젯을 제거하고, 웹 CSS의 `env(safe-area-inset-*)` 로 safe area를 직접 관리하는 방식입니다.

### 변경 내용

**1) Flutter — SafeArea 제거 + Edge-to-Edge 모드**

```dart
// main() 에서 edge-to-edge 활성화
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
SystemChrome.setSystemUIOverlayStyle(
  const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ),
);

// WebViewScreen.build() 에서 SafeArea 제거
Scaffold(
  body: Stack(  // SafeArea 없이 바로 Stack
    children: [
      WebViewWidget(controller: _controller),
    ],
  ),
)
```

**2) Web — viewport-fit: cover 추가**

```typescript
// layout.tsx
export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',  // ← 추가
  // ...
};
```

**3) Web — CSS에서 safe area padding 처리**

```css
/* globals.css */
body {
  padding-top: env(safe-area-inset-top, 0px);
}
```

### 결과: 실패

**문제점 1: 외부 페이지의 SafeArea 침범**

우리 웹앱 페이지는 CSS로 safe area를 처리할 수 있지만, **OAuth 로그인 등 외부 페이지**는 우리가 CSS를 제어할 수 없습니다.

카카오 로그인 페이지에서 콘텐츠가 status bar 영역까지 올라가는 현상이 발생했습니다.

**스크린샷**: (카카오 로그인 페이지에서 status bar 침범 스크린샷 첨부)

**문제점 2: 스크롤 시 SafeArea 침범**

외부 페이지에서 스크롤하면 콘텐츠가 status bar 영역으로 들어가는 문제도 발생했습니다.

**스크린샷**: (스크롤 시 SafeArea 침범 스크린샷 첨부)

### 결론

WebView 앱에서 CSS SafeArea 방식은 **우리가 제어할 수 있는 페이지에서만 동작**합니다. OAuth 등 외부 페이지를 다루는 앱에서는 적합하지 않습니다.

> 이 실험은 `git revert`로 롤백했습니다.

---

## 실험 2: JavaScript Channel 방식 (성공)

### 접근법

Flutter의 `SafeArea`를 유지하면서, **JavaScript Channel**을 통해 웹 → Flutter 에 배경색 변경을 요청하는 방식입니다.

SafeArea의 뒤쪽 Scaffold 배경색을 동적으로 변경해서, 통화 화면에서는 어두운 색, 일반 화면에서는 밝은 색으로 전환합니다.

```
[Web] 통화 화면 진입
  → window.HarukotoBridge.postMessage({type:'setTheme', bg:'#0f172a'})
  → [Flutter] Scaffold 배경색 변경 + status bar 아이콘 밝게

[Web] 통화 화면 퇴장
  → window.HarukotoBridge.postMessage({type:'setTheme', bg:'#ffffff'})
  → [Flutter] 원래 색 복원 + status bar 아이콘 어둡게
```

### 변경 내용

**1) Flutter — JavaScript Channel 등록**

```dart
class _WebViewScreenState extends State<WebViewScreen> {
  Color _scaffoldBgColor = Colors.white;

  void _onBridgeMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message);
    if (data['type'] == 'setTheme') {
      final color = Color(int.parse(data['bg'].replaceFirst('#', '0xFF')));
      final isLight = data['statusBar'] == 'light';

      setState(() => _scaffoldBgColor = color);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isLight ? Brightness.light : Brightness.dark,
      ));
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..addJavaScriptChannel('HarukotoBridge',
          onMessageReceived: _onBridgeMessage)
      // ... 나머지 설정
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,  // 동적 배경색
      body: SafeArea(  // SafeArea 유지!
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
```

**2) Web — Flutter 브릿지 유틸리티**

```typescript
// lib/flutter-bridge.ts
declare global {
  interface Window {
    HarukotoBridge?: { postMessage: (message: string) => void };
  }
}

export function postToFlutter(message: Record<string, unknown>) {
  window.HarukotoBridge?.postMessage(JSON.stringify(message));
}

export function setDarkTheme() {
  postToFlutter({ type: 'setTheme', bg: '#0f172a', statusBar: 'light' });
}

export function setLightTheme() {
  postToFlutter({ type: 'setTheme', bg: '#ffffff', statusBar: 'dark' });
}
```

**3) Web — 통화 페이지에서 사용**

```typescript
// chat/call/page.tsx
useEffect(() => {
  setDarkTheme();
  return () => setLightTheme();
}, []);
```

### 장점

- **SafeArea 유지**: 외부 페이지(OAuth 등)도 정상 동작
- **선택적 적용**: 필요한 페이지에서만 테마 변경
- **일반 브라우저 영향 없음**: `window.HarukotoBridge`가 없으면 무시됨
- **확장 가능**: 다른 Flutter ↔ Web 통신에도 활용 가능

### 최종 구현: 상/하단 독립 색상 + 다크모드 동기화

단순히 하나의 배경색이 아닌, **상단/하단 SafeArea를 독립적으로 제어**하도록 발전시켰습니다.

**Flutter — SafeArea를 수동 Container로 교체:**

```dart
body: Column(
  children: [
    Container(color: _topColor, height: MediaQuery.of(context).padding.top),
    Expanded(child: WebViewWidget(controller: _controller)),
    Container(color: _bottomColor, height: MediaQuery.of(context).padding.bottom),
  ],
)
```

**Web — 테마 변경 자동 감지:**

```typescript
// theme-provider.tsx
function FlutterThemeSync() {
  const { resolvedTheme } = useTheme();
  useEffect(() => {
    if (resolvedTheme === 'dark') setDarkTheme();
    else setLightTheme();
  }, [resolvedTheme]);
  return null;
}
```

**Web — 통화 화면 전용 그라데이션 대응:**

```typescript
// chat/call/page.tsx
useEffect(() => {
  setCallTheme(); // 상단: #0f172a, 하단: #000000
  return () => {
    const isDark = document.documentElement.classList.contains('dark');
    if (isDark) setDarkTheme();
    else setLightTheme();
  };
}, []);
```

### 결과: 성공

- 라이트 모드: SafeArea가 `#FFF8F0` (크림색)으로 페이지 배경과 일치
- 다크 모드: SafeArea가 `#1A1A2E` (진한 남색)으로 자동 전환
- 통화 화면: 상단 `slate-900` / 하단 `black` 으로 그라데이션과 매칭
- 외부 페이지 (OAuth 등): SafeArea가 유지되어 정상 동작

**스크린샷**: (각 모드별 SafeArea가 배경과 일치하는 스크린샷 첨부)

---

## 정리

| 방식 | SafeArea | 외부 페이지 | 상/하단 분리 | 다크모드 | 결과 |
|------|---------|------------|------------|---------|------|
| CSS SafeArea (`viewport-fit: cover`) | 제거 | 침범 문제 | - | - | 실패 |
| JavaScript Channel (단일 색상) | 유지 | 정상 | 불가 | 수동 | 부분 성공 |
| JavaScript Channel (상/하단 분리) | 수동 Container | 정상 | 가능 | 자동 | 성공 |

**핵심 교훈**:

1. WebView 앱에서 SafeArea를 제거하면 외부 페이지에서 문제가 발생한다
2. SafeArea는 유지하되, Flutter ↔ Web JavaScript Channel로 배경색을 동적으로 제어하는 것이 안전한 접근법이다
3. 상/하단을 독립 Container로 분리하면 그라데이션 배경에도 대응 가능하다
4. `next-themes`의 `useTheme()` + Flutter 브릿지를 조합하면 다크모드 전환도 자동 처리된다
