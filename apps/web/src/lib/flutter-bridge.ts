/**
 * Flutter WebView ↔ Web 브릿지
 * WebView 안에서만 동작하고, 일반 브라우저에서는 무시됩니다.
 */

declare global {
  interface Window {
    HarukotoBridge?: { postMessage: (message: string) => void };
  }
}

export function postToFlutter(message: Record<string, unknown>) {
  window.HarukotoBridge?.postMessage(JSON.stringify(message));
}

/** 통화 화면 진입 시 호출 — SafeArea 배경을 어둡게 */
export function setDarkTheme() {
  postToFlutter({ type: 'setTheme', bg: '#0f172a', statusBar: 'light' });
}

/** 통화 화면 퇴장 시 호출 — 원래 밝은 테마로 복원 */
export function setLightTheme() {
  postToFlutter({ type: 'setTheme', bg: '#ffffff', statusBar: 'dark' });
}
