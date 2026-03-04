import type { Metadata } from 'next';
import { Noto_Sans_KR, Noto_Sans_JP } from 'next/font/google';
import './globals.css';
import { ThemeProvider } from '@/components/providers/theme-provider';

const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL || 'https://www.harukoto.co.kr';

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
  metadataBase: new URL(SITE_URL),
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
  alternates: {
    canonical: '/',
  },
  openGraph: {
    title: '하루코토 - 매일 한 단어, 봄처럼 피어나는 나의 일본어',
    description:
      'JLPT 시험 대비부터 AI 회화 연습까지, 한국인을 위한 재미있는 일본어 학습 앱',
    type: 'website',
    locale: 'ko_KR',
    url: '/',
    siteName: '하루코토',
    images: [
      {
        url: '/images/og-image.png',
        width: 1200,
        height: 630,
        alt: '하루코토 - 매일 한 단어, 봄처럼 피어나는 나의 일본어',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: '하루코토 - 매일 한 단어, 봄처럼 피어나는 나의 일본어',
    description:
      'JLPT 시험 대비부터 AI 회화 연습까지, 한국인을 위한 재미있는 일본어 학습 앱',
    images: ['/images/og-image.png'],
  },
  icons: {
    icon: '/favicon.svg',
  },
  verification: {
    google: '8ig4BdUC_tedEa1u79uPwqjm9pcfbs6e0s5xYPiBjrs',
    other: {
      'naver-site-verification': '0f90303d9154978da76a527c7ed14989aeacdc49',
    },
  },
};

const organizationJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: '화이트마우스데브',
  alternateName: 'WhiteMouseDev',
  url: SITE_URL,
  logo: `${SITE_URL}/images/logo-symbol.svg`,
  contactPoint: {
    '@type': 'ContactPoint',
    email: 'whitemousedev@whitemouse.dev',
    contactType: 'customer service',
  },
};

const webApplicationJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'WebApplication',
  name: '하루코토',
  alternateName: 'HaruKoto',
  url: SITE_URL,
  applicationCategory: 'EducationalApplication',
  operatingSystem: 'Web, Android',
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'KRW',
  },
  description:
    'JLPT 시험 대비부터 AI 회화 연습까지, 한국인을 위한 재미있는 일본어 학습 앱',
  inLanguage: ['ko', 'ja'],
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
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify([organizationJsonLd, webApplicationJsonLd]),
          }}
        />
      </body>
    </html>
  );
}
