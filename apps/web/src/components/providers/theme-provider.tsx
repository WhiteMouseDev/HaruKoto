'use client';

import { useEffect } from 'react';
import { ThemeProvider as NextThemesProvider, useTheme } from 'next-themes';
import { setLightTheme, setDarkTheme } from '@/lib/flutter-bridge';

/** Flutter WebView SafeArea 색상을 현재 테마에 맞춰 동기화 */
function FlutterThemeSync() {
  const { resolvedTheme } = useTheme();

  useEffect(() => {
    if (resolvedTheme === 'dark') {
      setDarkTheme();
    } else {
      setLightTheme();
    }
  }, [resolvedTheme]);

  return null;
}

export function ThemeProvider({
  children,
  ...props
}: React.ComponentProps<typeof NextThemesProvider>) {
  return (
    <NextThemesProvider {...props}>
      <FlutterThemeSync />
      {children}
    </NextThemesProvider>
  );
}
