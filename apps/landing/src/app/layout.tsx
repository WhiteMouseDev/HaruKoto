import type { Metadata } from 'next';
import { Noto_Sans_KR, Noto_Sans_JP } from 'next/font/google';
import './globals.css';
import { ThemeProvider } from '@/components/providers/theme-provider';

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
  title: '하루코토 - 매일 한 단어, 봄처럼 피어나는 나의 일본어',
  description:
    'JLPT 시험 대비부터 AI 회화 연습까지, 한국인을 위한 재미있는 일본어 학습 앱. 매일 한 단어씩 봄처럼 피어나는 나의 일본어 실력!',
  keywords: [
    '일본어',
    'JLPT',
    '일본어 학습',
    'AI 회화',
    '하루코토',
    'HaruKoto',
    '일본어 공부',
    '일본어 단어',
  ],
  authors: [{ name: 'HaruKoto Team' }],
  openGraph: {
    title: '하루코토 - 매일 한 단어, 봄처럼 피어나는 나의 일본어',
    description:
      'JLPT 시험 대비부터 AI 회화 연습까지, 한국인을 위한 재미있는 일본어 학습 앱',
    type: 'website',
    locale: 'ko_KR',
  },
  icons: {
    icon: '/favicon.svg',
  },
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
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
