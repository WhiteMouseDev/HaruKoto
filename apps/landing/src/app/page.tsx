import {
  BookOpen,
  Bot,
  Gamepad2,
  Flower2,
  Download,
  Globe,
  ChevronRight,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  Header,
  Hero,
  AnimatedSection,
  MotionDiv,
  MotionCard,
  BrandLogo,
} from '@/components/landing/client-sections';

const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

const APK_DOWNLOAD_URL =
  'https://github.com/WhiteMouseDev/HaruKoto/releases/download/v1.0.0-beta/app-release.apk';

/* ─────────────────────────────────────────
   Features Section — Bento Grid
   ───────────────────────────────────────── */
function Features() {
  return (
    <AnimatedSection
      id="features"
      className="relative py-28"
      aria-label="주요 기능"
    >
      <div className="mx-auto max-w-7xl px-6">
        <MotionDiv className="max-w-xl">
          <p className="text-primary text-sm font-semibold tracking-wide uppercase">
            Features
          </p>
          <h2 className="text-foreground mt-3 text-3xl font-bold sm:text-4xl lg:text-5xl">
            왜 하루코토인가요?
          </h2>
          <p className="text-muted-foreground mt-4 text-lg leading-relaxed">
            효과적이고 재미있는 학습을 위한 모든 것을 담았어요
          </p>
        </MotionDiv>

        {/* Bento Grid — asymmetric layout */}
        <div className="mt-14 grid gap-4 sm:grid-cols-5 sm:grid-rows-2">
          {/* JLPT — large card, spans 3 cols */}
          <MotionDiv className="bg-card border-border/50 group relative overflow-hidden rounded-3xl border p-8 sm:col-span-3 sm:p-10">
            <div className="relative z-10">
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-hk-blue/10 text-hk-blue">
                <BookOpen className="h-5 w-5" />
              </div>
              <h3 className="text-foreground mt-5 text-xl font-bold">
                JLPT 완벽 대비
              </h3>
              <p className="text-muted-foreground mt-2 max-w-sm leading-relaxed">
                N5부터 N1까지, 체계적인 단어와 문법 학습.
                실전 모의고사로 시험 대비를 완벽하게.
              </p>
              {/* Decorative JLPT level pills */}
              <div className="mt-6 flex flex-wrap gap-2">
                {['N5', 'N4', 'N3', 'N2', 'N1'].map((level) => (
                  <span
                    key={level}
                    className="border-border bg-background rounded-full border px-3 py-1 text-xs font-medium"
                  >
                    {level}
                  </span>
                ))}
              </div>
            </div>
            <div
              className="text-primary/[0.04] pointer-events-none absolute -right-6 -bottom-4 text-[180px] font-black select-none"
              aria-hidden="true"
            >
              漢
            </div>
          </MotionDiv>

          {/* AI 회화 — spans 2 cols */}
          <MotionDiv className="bg-card border-border/50 group relative overflow-hidden rounded-3xl border p-8 sm:col-span-2">
            <div className="relative z-10">
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-hk-green/10 text-hk-green">
                <Bot className="h-5 w-5" />
              </div>
              <h3 className="text-foreground mt-5 text-xl font-bold">
                AI 실전 회화
              </h3>
              <p className="text-muted-foreground mt-2 leading-relaxed">
                AI와 자연스러운 일본어 대화 연습.
                실시간 피드백으로 회화 실력 향상.
              </p>
            </div>
            {/* Decorative chat bubbles */}
            <div className="mt-6 space-y-2">
              <div className="bg-secondary w-fit rounded-2xl rounded-bl-sm px-4 py-2">
                <span className="font-jp text-foreground text-xs">
                  今日の天気はどうですか？
                </span>
              </div>
              <div className="bg-primary/10 ml-auto w-fit rounded-2xl rounded-br-sm px-4 py-2">
                <span className="text-foreground text-xs">
                  오늘 날씨가 어떤가요?
                </span>
              </div>
            </div>
          </MotionDiv>

          {/* 게이미피케이션 — spans 2 cols */}
          <MotionDiv className="bg-card border-border/50 group relative overflow-hidden rounded-3xl border p-8 sm:col-span-2">
            <div className="relative z-10">
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-hk-yellow/10 text-hk-yellow">
                <Gamepad2 className="h-5 w-5" />
              </div>
              <h3 className="text-foreground mt-5 text-xl font-bold">
                게이미피케이션
              </h3>
              <p className="text-muted-foreground mt-2 leading-relaxed">
                XP, 레벨업, 연속 학습 보상으로
                매일 학습이 즐거워져요.
              </p>
            </div>
            {/* Decorative progress bar */}
            <div className="mt-6 space-y-3">
              <div className="flex items-center justify-between text-xs">
                <span className="text-foreground font-semibold">Lv. 12</span>
                <span className="text-muted-foreground">2,450 / 3,000 XP</span>
              </div>
              <div className="bg-muted h-2.5 overflow-hidden rounded-full">
                <div className="bg-primary h-full w-[82%] rounded-full" />
              </div>
            </div>
          </MotionDiv>

          {/* 매일 한 단어 — large card, spans 3 cols */}
          <MotionDiv className="bg-card border-border/50 group relative overflow-hidden rounded-3xl border p-8 sm:col-span-3 sm:p-10">
            <div className="relative z-10 flex flex-col justify-between sm:flex-row sm:items-center sm:gap-10">
              <div>
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary">
                  <Flower2 className="h-5 w-5" />
                </div>
                <h3 className="text-foreground mt-5 text-xl font-bold">
                  매일 한 단어
                </h3>
                <p className="text-muted-foreground mt-2 max-w-sm leading-relaxed">
                  하루에 한 단어씩, 부담 없이 꾸준히.
                  봄처럼 자연스럽게 실력이 피어납니다.
                </p>
              </div>
              {/* Decorative word card */}
              <div className="bg-secondary/60 mt-6 flex-shrink-0 rounded-2xl p-6 text-center sm:mt-0">
                <p className="text-muted-foreground text-xs font-medium">오늘의 단어</p>
                <p className="font-jp text-foreground mt-2 text-4xl font-bold">花見</p>
                <p className="text-muted-foreground font-jp mt-1 text-sm">はなみ</p>
                <p className="text-foreground mt-1.5 text-sm font-medium">꽃구경</p>
              </div>
            </div>
          </MotionDiv>
        </div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   How It Works Section
   ───────────────────────────────────────── */
const steps = [
  {
    number: '01',
    title: '레벨 선택',
    description: '나의 일본어 수준에 맞는 JLPT 레벨을 선택하세요. 처음이어도 괜찮아요.',
    accent: 'from-hk-blue/20 to-hk-blue/5',
  },
  {
    number: '02',
    title: '매일 학습',
    description: '하루 10분, 단어와 문법을 퀴즈로 재미있게. 게임처럼 즐기다 보면 어느새.',
    accent: 'from-hk-green/20 to-hk-green/5',
  },
  {
    number: '03',
    title: '실전 회화',
    description: 'AI와 자연스러운 대화로 배운 것을 바로 써먹어요. 틀려도 괜찮아요.',
    accent: 'from-primary/20 to-primary/5',
  },
];

function HowItWorks() {
  return (
    <AnimatedSection
      id="how-it-works"
      className="py-28"
      aria-label="학습 방법"
    >
      <div className="mx-auto max-w-7xl px-6">
        <MotionDiv className="text-center">
          <p className="text-primary text-sm font-semibold tracking-wide uppercase">
            How it works
          </p>
          <h2 className="text-foreground mt-3 text-3xl font-bold sm:text-4xl lg:text-5xl">
            3단계로 시작하는 일본어
          </h2>
        </MotionDiv>

        <div className="mt-16 space-y-4 sm:space-y-5">
          {steps.map((step) => (
            <MotionDiv
              key={step.number}
              className={cn(
                'relative overflow-hidden rounded-2xl bg-gradient-to-r p-8 sm:rounded-3xl sm:p-10',
                step.accent
              )}
            >
              <div className="relative z-10 flex flex-col gap-4 sm:flex-row sm:items-center sm:gap-10">
                <span
                  className="text-foreground/10 text-6xl font-black sm:text-8xl"
                  aria-hidden="true"
                >
                  {step.number}
                </span>
                <div>
                  <h3 className="text-foreground text-xl font-bold sm:text-2xl">
                    {step.title}
                  </h3>
                  <p className="text-muted-foreground mt-2 max-w-lg leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </div>
            </MotionDiv>
          ))}
        </div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   Stats — full-width minimal band
   ───────────────────────────────────────── */
function Stats() {
  const stats = [
    { value: '10,000+', label: '수록 단어' },
    { value: 'N5 → N1', label: '전 레벨 지원' },
    { value: '∞', label: 'AI 회화 무제한' },
  ];

  return (
    <AnimatedSection
      className="border-border/50 border-y py-16"
      aria-label="주요 수치"
    >
      <div className="mx-auto max-w-5xl px-6">
        <div className="grid grid-cols-3 divide-x divide-border">
          {stats.map((stat) => (
            <MotionDiv key={stat.label} className="px-4 text-center sm:px-8">
              <div className="text-foreground text-2xl font-bold tracking-tight sm:text-4xl">
                {stat.value}
              </div>
              <div className="text-muted-foreground mt-1.5 text-xs font-medium sm:text-sm">
                {stat.label}
              </div>
            </MotionDiv>
          ))}
        </div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   Beta Download Section
   ───────────────────────────────────────── */
function BetaDownload() {
  return (
    <AnimatedSection
      id="download"
      className="bg-secondary/30 py-24"
      aria-label="앱 다운로드"
    >
      <div className="mx-auto max-w-4xl px-6">
        <MotionDiv className="text-center">
          <span className="bg-primary/10 text-primary inline-block rounded-full px-4 py-1.5 text-sm font-semibold">
            Beta
          </span>
          <h2 className="text-foreground mt-4 text-3xl font-bold sm:text-4xl">
            앱 다운로드
          </h2>
          <p className="text-muted-foreground mx-auto mt-4 max-w-2xl text-lg">
            지금 바로 하루코토를 체험해보세요
          </p>
        </MotionDiv>

        <div className="mt-12 grid gap-6 sm:grid-cols-2">
          {/* Android APK */}
          <MotionCard
            href={APK_DOWNLOAD_URL}
            className="bg-card border-border/50 flex flex-col items-center gap-4 rounded-2xl border p-8 shadow-sm transition-shadow hover:shadow-lg"
          >
            <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-green-100 text-green-600">
              <Download className="h-7 w-7" />
            </div>
            <div className="text-center">
              <h3 className="text-foreground text-lg font-bold">
                Android 다운로드
              </h3>
              <p className="text-muted-foreground mt-1 text-sm">
                APK 직접 설치 (v1.0.0-beta)
              </p>
            </div>
            <span className="bg-primary/10 text-primary rounded-full px-4 py-2 text-sm font-semibold">
              APK 다운로드
            </span>
          </MotionCard>

          {/* Web App */}
          <MotionCard
            href={APP_URL}
            className="bg-card border-border/50 flex flex-col items-center gap-4 rounded-2xl border p-8 shadow-sm transition-shadow hover:shadow-lg"
          >
            <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-blue-100 text-blue-600">
              <Globe className="h-7 w-7" />
            </div>
            <div className="text-center">
              <h3 className="text-foreground text-lg font-bold">
                웹으로 시작하기
              </h3>
              <p className="text-muted-foreground mt-1 text-sm">
                iOS / PC 모두 지원
              </p>
            </div>
            <span className="bg-primary/10 text-primary rounded-full px-4 py-2 text-sm font-semibold">
              웹앱 열기
            </span>
          </MotionCard>
        </div>

        <MotionDiv className="mt-6 text-center">
          <p className="text-muted-foreground text-xs">
            * Android APK 설치 시 &quot;출처를 알 수 없는 앱&quot; 허용이
            필요합니다
          </p>
        </MotionDiv>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   Final CTA Section
   ───────────────────────────────────────── */
function FinalCTA() {
  return (
    <AnimatedSection
      id="cta"
      className="relative overflow-hidden py-28 sm:py-36"
      aria-label="시작하기"
    >
      {/* Layered gradient background */}
      <div
        className="absolute inset-0 bg-gradient-to-br from-[#FFB7C5] via-[#FFD0DB] to-[#FFE4EC]"
        aria-hidden="true"
      />
      <div
        className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_left,rgba(255,255,255,0.4),transparent_50%)]"
        aria-hidden="true"
      />
      <div
        className="absolute inset-0 bg-[radial-gradient(ellipse_at_bottom_right,rgba(255,143,163,0.3),transparent_50%)]"
        aria-hidden="true"
      />

      {/* Decorative kanji */}
      <div
        className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-[280px] font-black text-white/[0.08] select-none sm:text-[400px]"
        aria-hidden="true"
      >
        春
      </div>

      <div className="relative mx-auto max-w-2xl px-6 text-center">
        <MotionDiv>
          <p className="font-jp text-sm font-medium text-white/60">
            毎日一言、春のように
          </p>
        </MotionDiv>
        <MotionDiv>
          <h2 className="mt-4 text-3xl font-bold text-white sm:text-4xl lg:text-5xl">
            지금 바로 시작하세요
          </h2>
        </MotionDiv>
        <MotionDiv>
          <p className="mt-4 text-base text-white/70 sm:text-lg">
            매일 10분, 당신의 일본어가 달라집니다
          </p>
        </MotionDiv>
        <MotionDiv className="mt-10">
          <a
            href={APP_URL}
            className="inline-flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-bold text-[#FF8FA3] shadow-lg transition-all hover:bg-white/90 hover:shadow-xl"
          >
            무료로 시작하기
            <ChevronRight className="h-5 w-5" />
          </a>
        </MotionDiv>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   Footer
   ───────────────────────────────────────── */
function Footer() {
  return (
    <footer className="border-border/50 border-t py-12">
      <div className="mx-auto max-w-7xl px-6">
        <div className="flex flex-col items-center gap-6 sm:flex-row sm:justify-between">
          <BrandLogo size="sm" />

          <nav className="flex flex-wrap justify-center gap-6" aria-label="푸터 네비게이션">
            <a
              href="/terms"
              className="text-muted-foreground hover:text-foreground text-sm transition-colors"
            >
              이용약관
            </a>
            <a
              href="/privacy"
              className="text-muted-foreground hover:text-foreground text-sm transition-colors"
            >
              개인정보처리방침
            </a>
            <a
              href="mailto:whitemousedev@whitemouse.dev"
              className="text-muted-foreground hover:text-foreground text-sm transition-colors"
            >
              문의하기
            </a>
          </nav>
        </div>

        <div className="text-muted-foreground mt-8 space-y-1 text-center text-xs">
          <p>
            화이트마우스데브 (WhiteMouseDev) | 대표: 김건우 |
            사업자등록번호: 634-26-01985 | 통신판매업신고번호: 2026-서울송파-0749
          </p>
          <p>서울특별시 송파구 양재대로 1218</p>
          <p className="mt-2">&copy; 2025 하루코토. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}

/* ─────────────────────────────────────────
   Page Composition
   ───────────────────────────────────────── */
export default function LandingPage() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Stats />
        <BetaDownload />
        <FinalCTA />
      </main>
      <Footer />
    </>
  );
}
