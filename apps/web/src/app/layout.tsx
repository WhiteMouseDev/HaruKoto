import type { Metadata, Viewport } from 'next';
import { Noto_Sans_KR, Noto_Sans_JP } from 'next/font/google';
import './globals.css';
import { ThemeProvider } from '@/components/providers/theme-provider';
import { QueryProvider } from '@/components/providers/query-provider';
import { PWARegister } from '@/components/pwa-register';
import { Toaster } from 'sonner';

const notoSansKR = Noto_Sans_KR({
  variable: '--font-noto-sans-kr',
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  display: 'swap',
});

const notoSansJP = Noto_Sans_JP({
  variable: '--font-noto-sans-jp',
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  display: 'swap',
});

export const metadata: Metadata = {
  title: {
    default: '하루코토 - 매일 한 단어, 봄처럼 피어나는 나의 일본어',
    template: '%s | 하루코토',
  },
  description:
    'JLPT 시험 대비부터 AI 회화 연습까지, 한국인을 위한 재미있는 일본어 학습 앱',
  keywords: [
    '일본어',
    'JLPT',
    '일본어 학습',
    'AI 회화',
    '하루코토',
    'HaruKoto',
  ],
  authors: [{ name: 'HaruKoto Team' }],
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: '하루코토',
  },
  icons: {
    icon: '/favicon.svg',
    apple: '/icons/apple-touch-icon.svg',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: 'cover',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#FFB7C5' },
    { media: '(prefers-color-scheme: dark)', color: '#FF8FA3' },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ko" suppressHydrationWarning>
      <body
        className={`${notoSansKR.variable} ${notoSansJP.variable} antialiased`}
      >
        <ThemeProvider
          attribute="class"
          defaultTheme="light"
          enableSystem
          disableTransitionOnChange
        >
          <QueryProvider>{children}</QueryProvider>
        </ThemeProvider>
        <PWARegister />
        <Toaster
          position="top-center"
          richColors
          toastOptions={{
            style: {
              background: 'var(--card)',
              border: '1px solid var(--border)',
              color: 'var(--foreground)',
            },
          }}
        />
      </body>
    </html>
  );
}
