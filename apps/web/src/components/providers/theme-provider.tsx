'use client';

import { useEffect } from 'react';
import { ThemeProvider as NextThemesProvider, useTheme } from 'next-themes';
import { setLightTheme, setDarkTheme } from '@/lib/flutter-bridge';

const THEME_COLORS = {
  light: '#F6A5B3',
  dark: '#1A1A2E',
} as const;

/** Flutter WebView SafeArea + meta theme-color을 현재 테마에 맞춰 동기화 */
function ThemeSync() {
  const { resolvedTheme } = useTheme();

  useEffect(() => {
    if (resolvedTheme === 'dark') {
      setDarkTheme();
    } else {
      setLightTheme();
    }

    // meta theme-color 동기화 (SafeArea 색상)
    const color = resolvedTheme === 'dark' ? THEME_COLORS.dark : THEME_COLORS.light;
    document
      .querySelectorAll('meta[name="theme-color"]')
      .forEach((el) => el.setAttribute('content', color));
  }, [resolvedTheme]);

  return null;
}

export function ThemeProvider({
  children,
  ...props
}: React.ComponentProps<typeof NextThemesProvider>) {
  return (
    <NextThemesProvider {...props}>
      <ThemeSync />
      {children}
    </NextThemesProvider>
  );
}
