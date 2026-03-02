'use client';

import { useTheme } from 'next-themes';

export function useThemeToggle() {
  const { theme, setTheme, resolvedTheme } = useTheme();

  function toggle() {
    setTheme(resolvedTheme === 'dark' ? 'light' : 'dark');
  }

  return {
    theme,
    setTheme,
    resolvedTheme,
    toggle,
    isDark: resolvedTheme === 'dark',
  };
}
