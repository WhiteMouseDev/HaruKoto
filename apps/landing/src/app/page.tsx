'use client';

import { useEffect, useRef, useState } from 'react';
import { motion, useInView } from 'framer-motion';
import { Logo } from '@/components/brand/logo';
import { cn } from '@/lib/utils';
import {
  BookOpen,
  Bot,
  Gamepad2,
  Flower2,
  ChevronRight,
  ArrowDown,
} from 'lucide-react';

/* ─────────────────────────────────────────
   Cherry Blossom Petal CSS Animation
   ───────────────────────────────────────── */
function CherryBlossomStyles() {
  return (
    <style>{`
      @keyframes petal-fall {
        0% {
          transform: translateY(-10vh) translateX(0) rotate(0deg);
          opacity: 1;
        }
        25% {
          transform: translateY(20vh) translateX(30px) rotate(90deg);
          opacity: 0.9;
        }
        50% {
          transform: translateY(45vh) translateX(-20px) rotate(180deg);
          opacity: 0.7;
        }
        75% {
          transform: translateY(70vh) translateX(25px) rotate(270deg);
          opacity: 0.4;
        }
        100% {
          transform: translateY(100vh) translateX(-10px) rotate(360deg);
          opacity: 0;
        }
      }

      @keyframes petal-sway {
        0%, 100% { transform: translateX(0); }
        50% { transform: translateX(15px); }
      }

      .petal {
        position: absolute;
        width: 12px;
        height: 12px;
        background: radial-gradient(ellipse at center, #FFB7C5 0%, #FFD6E0 60%, transparent 70%);
        border-radius: 50% 0 50% 0;
        animation: petal-fall linear infinite;
        pointer-events: none;
      }
    `}</style>
  );
}

function FloatingPetals() {
  const petals = [
    { left: '10%', delay: '0s', duration: '8s', size: 14 },
    { left: '25%', delay: '2s', duration: '10s', size: 10 },
    { left: '40%', delay: '4s', duration: '9s', size: 16 },
    { left: '55%', delay: '1s', duration: '11s', size: 12 },
    { left: '70%', delay: '3s', duration: '8.5s', size: 10 },
    { left: '85%', delay: '5s', duration: '9.5s', size: 14 },
    { left: '15%', delay: '6s', duration: '10.5s', size: 11 },
  ];

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {petals.map((p, i) => (
        <div
          key={i}
          className="petal"
          style={{
            left: p.left,
            top: '-20px',
            width: p.size,
            height: p.size,
            animationDelay: p.delay,
            animationDuration: p.duration,
            opacity: 0.7,
          }}
        />
      ))}
    </div>
  );
}

/* ─────────────────────────────────────────
   Shared Animation Variants
   ───────────────────────────────────────── */
const fadeInUp = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: 'easeOut' as const } },
};

const staggerContainer = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.15 },
  },
};

function AnimatedSection({
  children,
  className,
  id,
}: {
  children: React.ReactNode;
  className?: string;
  id?: string;
}) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });

  return (
    <motion.section
      ref={ref}
      id={id}
      initial="hidden"
      animate={isInView ? 'visible' : 'hidden'}
      variants={staggerContainer}
      className={className}
    >
      {children}
    </motion.section>
  );
}

/* ─────────────────────────────────────────
   1. Navigation Header
   ───────────────────────────────────────── */
function Header() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const scrollTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <header
      className={cn(
        'fixed top-0 right-0 left-0 z-50 transition-all duration-300',
        scrolled
          ? 'border-border/50 bg-background/80 border-b backdrop-blur-lg'
          : 'bg-transparent'
      )}
    >
      <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
        <Logo variant="full" size="sm" />

        <nav className="hidden items-center gap-8 md:flex">
          <button
            onClick={() => scrollTo('features')}
            className="text-muted-foreground hover:text-foreground text-sm font-medium transition-colors"
          >
            기능
          </button>
          <button
            onClick={() => scrollTo('how-it-works')}
            className="text-muted-foreground hover:text-foreground text-sm font-medium transition-colors"
          >
            학습방법
          </button>
          <button
            onClick={() => scrollTo('cta')}
            className="text-muted-foreground hover:text-foreground text-sm font-medium transition-colors"
          >
            시작하기
          </button>
        </nav>

        <a
          href="#"
          className="bg-primary hover:bg-hk-primary-hover rounded-full px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:shadow-md"
        >
          시작하기
        </a>
      </div>
    </header>
  );
}

/* ─────────────────────────────────────────
   2. Hero Section
   ───────────────────────────────────────── */
function Hero() {
  return (
    <section className="relative flex min-h-screen items-center overflow-hidden pt-20">
      <FloatingPetals />

      {/* Background decorative circles */}
      <div className="bg-primary/10 absolute -top-40 -right-40 h-[500px] w-[500px] rounded-full blur-3xl" />
      <div className="bg-accent/30 absolute -bottom-20 -left-20 h-[400px] w-[400px] rounded-full blur-3xl" />

      <div className="relative mx-auto max-w-7xl px-6">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          {/* Left: Text */}
          <motion.div
            initial="hidden"
            animate="visible"
            variants={staggerContainer}
          >
            <motion.h1
              variants={fadeInUp}
              className="text-foreground text-5xl leading-tight font-bold tracking-tight sm:text-6xl lg:text-7xl"
            >
              매일 한 단어,
              <br />
              <span className="text-primary">봄처럼 피어나는</span>
              <br />
              나의 일본어
            </motion.h1>

            <motion.p
              variants={fadeInUp}
              className="text-muted-foreground mt-6 max-w-lg text-lg leading-relaxed"
            >
              JLPT 시험 대비부터 AI 실전 회화까지,
              <br className="hidden sm:block" />
              한국인을 위한 재미있는 일본어 학습 앱
            </motion.p>

            <motion.div variants={fadeInUp} className="mt-10 flex flex-wrap gap-4">
              <a
                href="#"
                className="bg-primary hover:bg-hk-primary-hover inline-flex items-center gap-2 rounded-full px-8 py-4 text-base font-semibold text-white shadow-lg transition-all hover:shadow-xl"
              >
                무료로 시작하기
                <ChevronRight className="h-4 w-4" />
              </a>
              <button
                onClick={() =>
                  document
                    .getElementById('features')
                    ?.scrollIntoView({ behavior: 'smooth' })
                }
                className="border-border text-foreground hover:bg-secondary inline-flex items-center gap-2 rounded-full border px-8 py-4 text-base font-semibold transition-all"
              >
                기능 둘러보기
                <ArrowDown className="h-4 w-4" />
              </button>
            </motion.div>
          </motion.div>

          {/* Right: Phone Mockup */}
          <motion.div
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.3, ease: 'easeOut' }}
            className="flex justify-center lg:justify-end"
          >
            <div className="relative">
              {/* Phone frame */}
              <div className="border-border/50 bg-card relative h-[580px] w-[280px] overflow-hidden rounded-[2.5rem] border-4 shadow-2xl">
                {/* Status bar */}
                <div className="bg-card flex items-center justify-center px-6 pt-3 pb-2">
                  <div className="bg-foreground h-5 w-20 rounded-full opacity-20" />
                </div>

                {/* App content preview */}
                <div className="space-y-4 p-4">
                  {/* Greeting */}
                  <div className="space-y-1">
                    <div className="text-muted-foreground text-xs">おはよう!</div>
                    <div className="text-foreground text-sm font-semibold">
                      오늘의 학습을 시작해볼까요?
                    </div>
                  </div>

                  {/* Stats cards */}
                  <div className="grid grid-cols-2 gap-2">
                    <div className="bg-primary/10 rounded-xl p-3">
                      <div className="text-primary text-lg font-bold">7일</div>
                      <div className="text-muted-foreground text-[10px]">연속 학습</div>
                    </div>
                    <div className="bg-accent rounded-xl p-3">
                      <div className="text-foreground text-lg font-bold">Lv.12</div>
                      <div className="text-muted-foreground text-[10px]">현재 레벨</div>
                    </div>
                  </div>

                  {/* Today's word card */}
                  <div className="bg-secondary rounded-2xl p-4">
                    <div className="text-muted-foreground mb-2 text-[10px] font-medium">
                      오늘의 단어
                    </div>
                    <div className="font-jp text-foreground text-2xl font-bold">桜</div>
                    <div className="text-muted-foreground mt-0.5 text-xs">さくら</div>
                    <div className="text-foreground mt-1 text-sm">벚꽃</div>
                  </div>

                  {/* Quick actions */}
                  <div className="space-y-2">
                    <div className="bg-primary flex items-center justify-between rounded-xl px-4 py-3 text-white">
                      <span className="text-xs font-semibold">JLPT N3 퀴즈</span>
                      <ChevronRight className="h-3.5 w-3.5" />
                    </div>
                    <div className="border-border flex items-center justify-between rounded-xl border px-4 py-3">
                      <span className="text-foreground text-xs font-semibold">
                        AI 회화 연습
                      </span>
                      <ChevronRight className="text-muted-foreground h-3.5 w-3.5" />
                    </div>
                  </div>
                </div>
              </div>

              {/* Glow effect behind phone */}
              <div className="bg-primary/20 absolute -inset-4 -z-10 rounded-[3rem] blur-2xl" />
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}

/* ─────────────────────────────────────────
   3. Features Section
   ───────────────────────────────────────── */
const features = [
  {
    icon: BookOpen,
    emoji: '📚',
    title: 'JLPT 완벽 대비',
    description:
      'N5부터 N1까지, 체계적인 단어와 문법 학습. 실전 모의고사로 시험 대비를 완벽하게.',
    color: 'bg-hk-blue/15 text-hk-blue',
  },
  {
    icon: Bot,
    emoji: '🤖',
    title: 'AI 실전 회화',
    description:
      'AI와 자연스러운 일본어 대화 연습. 실시간 피드백으로 회화 실력 향상.',
    color: 'bg-hk-green/15 text-hk-green',
  },
  {
    icon: Gamepad2,
    emoji: '🎮',
    title: '게이미피케이션',
    description:
      'XP, 레벨업, 연속 학습 보상으로 매일 학습이 즐거워져요.',
    color: 'bg-hk-yellow/15 text-hk-yellow',
  },
  {
    icon: Flower2,
    emoji: '🌸',
    title: '매일 한 단어',
    description:
      '하루에 한 단어씩, 부담 없이 꾸준히. 봄처럼 자연스럽게 실력이 피어납니다.',
    color: 'bg-primary/15 text-primary',
  },
];

function Features() {
  return (
    <AnimatedSection
      id="features"
      className="relative py-24"
    >
      <div className="mx-auto max-w-7xl px-6">
        <motion.div variants={fadeInUp} className="text-center">
          <h2 className="text-foreground text-3xl font-bold sm:text-4xl">
            왜 <span className="text-primary">하루코토</span>인가요?
          </h2>
          <p className="text-muted-foreground mx-auto mt-4 max-w-2xl text-lg">
            효과적이고 재미있는 학습을 위한 모든 것을 담았어요
          </p>
        </motion.div>

        <div className="mt-16 grid gap-6 sm:grid-cols-2">
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={fadeInUp}
              whileHover={{ scale: 1.02, y: -4 }}
              transition={{ type: 'spring', stiffness: 300, damping: 20 }}
              className="bg-card border-border/50 group rounded-2xl border p-8 shadow-sm transition-shadow hover:shadow-lg"
            >
              <div className="flex items-start gap-4">
                <div
                  className={cn(
                    'flex h-12 w-12 shrink-0 items-center justify-center rounded-xl text-xl',
                    feature.color
                  )}
                >
                  {feature.emoji}
                </div>
                <div>
                  <h3 className="text-foreground text-lg font-bold">
                    {feature.title}
                  </h3>
                  <p className="text-muted-foreground mt-2 leading-relaxed">
                    {feature.description}
                  </p>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   4. How It Works Section
   ───────────────────────────────────────── */
const steps = [
  {
    number: '1',
    title: '레벨 선택',
    description: '나의 일본어 수준에 맞는 JLPT 레벨을 선택하세요',
  },
  {
    number: '2',
    title: '매일 학습',
    description: '하루 10분, 단어와 문법을 퀴즈로 재미있게 학습',
  },
  {
    number: '3',
    title: '실전 회화',
    description: 'AI와 자연스러운 대화로 실력을 확인하세요',
  },
];

function HowItWorks() {
  return (
    <AnimatedSection
      id="how-it-works"
      className="bg-secondary/30 py-24"
    >
      <div className="mx-auto max-w-7xl px-6">
        <motion.div variants={fadeInUp} className="text-center">
          <h2 className="text-foreground text-3xl font-bold sm:text-4xl">
            <span className="text-primary">3단계</span>로 시작하는 일본어
          </h2>
          <p className="text-muted-foreground mx-auto mt-4 max-w-2xl text-lg">
            복잡한 준비 없이, 바로 시작할 수 있어요
          </p>
        </motion.div>

        <div className="mt-16 grid gap-8 md:grid-cols-3">
          {steps.map((step, i) => (
            <motion.div
              key={step.number}
              variants={fadeInUp}
              className="relative text-center"
            >
              {/* Connecting line (desktop only) */}
              {i < steps.length - 1 && (
                <div className="border-primary/30 absolute top-8 left-[calc(50%+2rem)] hidden h-0 w-[calc(100%-4rem)] border-t-2 border-dashed md:block" />
              )}

              <div className="bg-primary mx-auto flex h-16 w-16 items-center justify-center rounded-full text-2xl font-bold text-white shadow-lg">
                {step.number}
              </div>
              <h3 className="text-foreground mt-6 text-xl font-bold">
                {step.title}
              </h3>
              <p className="text-muted-foreground mx-auto mt-3 max-w-xs leading-relaxed">
                {step.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   5. Stats / Social Proof Section
   ───────────────────────────────────────── */
function AnimatedCounter({ value, label }: { value: string; label: string }) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true });

  return (
    <motion.div
      ref={ref}
      variants={fadeInUp}
      className="text-center"
    >
      <motion.div
        initial={{ scale: 0.5, opacity: 0 }}
        animate={isInView ? { scale: 1, opacity: 1 } : {}}
        transition={{ duration: 0.5, type: 'spring', stiffness: 200 }}
        className="text-primary text-4xl font-bold sm:text-5xl"
      >
        {value}
      </motion.div>
      <div className="text-muted-foreground mt-2 text-base font-medium">
        {label}
      </div>
    </motion.div>
  );
}

function Stats() {
  return (
    <AnimatedSection className="py-24">
      <div className="mx-auto max-w-4xl px-6">
        <div className="bg-card border-border/50 grid grid-cols-1 gap-10 rounded-3xl border p-10 shadow-sm sm:grid-cols-3 sm:gap-6">
          <AnimatedCounter value="10,000+" label="단어 수록" />
          <AnimatedCounter value="JLPT N5~N1" label="전 레벨 지원" />
          <AnimatedCounter value="AI 회화" label="무제한 연습" />
        </div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   6. Final CTA Section
   ───────────────────────────────────────── */
function FinalCTA() {
  return (
    <AnimatedSection id="cta" className="relative overflow-hidden py-24">
      {/* Gradient background */}
      <div className="absolute inset-0 bg-gradient-to-br from-[#FFB7C5] via-[#FFD6E0] to-[#FFE4EC]" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_50%,rgba(255,255,255,0.3),transparent_60%)]" />

      <div className="relative mx-auto max-w-3xl px-6 text-center">
        <motion.h2
          variants={fadeInUp}
          className="text-3xl font-bold text-white sm:text-4xl lg:text-5xl"
        >
          지금 바로 시작하세요
        </motion.h2>
        <motion.p
          variants={fadeInUp}
          className="mt-4 text-lg text-white/80"
        >
          매일 10분, 당신의 일본어가 달라집니다
        </motion.p>
        <motion.div variants={fadeInUp} className="mt-10">
          <a
            href="#"
            className="inline-flex items-center gap-2 rounded-full bg-white px-10 py-4 text-base font-bold text-[#FFB7C5] shadow-lg transition-all hover:bg-white/90 hover:shadow-xl"
          >
            무료로 시작하기
            <ChevronRight className="h-5 w-5" />
          </a>
        </motion.div>
      </div>
    </AnimatedSection>
  );
}

/* ─────────────────────────────────────────
   7. Footer
   ───────────────────────────────────────── */
function Footer() {
  return (
    <footer className="border-border/50 border-t py-12">
      <div className="mx-auto max-w-7xl px-6">
        <div className="flex flex-col items-center gap-6 sm:flex-row sm:justify-between">
          <Logo variant="full" size="sm" />

          <nav className="flex flex-wrap justify-center gap-6">
            <a
              href="#"
              className="text-muted-foreground hover:text-foreground text-sm transition-colors"
            >
              이용약관
            </a>
            <a
              href="#"
              className="text-muted-foreground hover:text-foreground text-sm transition-colors"
            >
              개인정보처리방침
            </a>
            <a
              href="#"
              className="text-muted-foreground hover:text-foreground text-sm transition-colors"
            >
              문의하기
            </a>
          </nav>
        </div>

        <div className="text-muted-foreground mt-8 text-center text-sm">
          &copy; 2025 하루코토. All rights reserved.
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
      <CherryBlossomStyles />
      <Header />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Stats />
        <FinalCTA />
      </main>
      <Footer />
    </>
  );
}
