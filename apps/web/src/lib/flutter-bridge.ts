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

type ThemeColors = {
  topColor: string;
  bottomColor: string;
  statusBar: 'light' | 'dark';
};

export function setThemeColors({ topColor, bottomColor, statusBar }: ThemeColors) {
  postToFlutter({ type: 'setTheme', topColor, bottomColor, statusBar });
}

/** 라이트 테마 기본 색상 */
export function setLightTheme() {
  setThemeColors({ topColor: '#FFF8F0', bottomColor: '#FFF8F0', statusBar: 'dark' });
}

/** 다크 테마 기본 색상 */
export function setDarkTheme() {
  setThemeColors({ topColor: '#1A1A2E', bottomColor: '#1A1A2E', statusBar: 'light' });
}

/** 통화 화면 (그라데이션: slate-900 → black) */
export function setCallTheme() {
  setThemeColors({ topColor: '#0f172a', bottomColor: '#000000', statusBar: 'light' });
}

/** 외부 URL 열기 — WebView에서는 Flutter url_launcher, 일반 브라우저에서는 window.open */
export function openExternalUrl(url: string) {
  if (window.HarukotoBridge) {
    postToFlutter({ type: 'openUrl', url });
  } else {
    window.open(url, '_blank');
  }
}
