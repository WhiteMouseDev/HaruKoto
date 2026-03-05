'use client';

import { usePathname } from 'next/navigation';

export function MainContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  // Chat conversation & call pages don't have bottom nav
  const hideBottomPadding =
    /^\/chat\/[^/]+$/.test(pathname) || pathname.startsWith('/chat/call');

  return (
    <main
      className={`mx-auto w-full max-w-lg flex-1 ${hideBottomPadding ? '' : 'pb-20'}`}
    >
      {children}
    </main>
  );
}
