'use client';

import { useEffect, useRef, useState } from 'react';
import { motion, useInView } from 'framer-motion';
import Image from 'next/image';
import { ChevronRight, ArrowDown } from 'lucide-react';
import { cn } from '@/lib/utils';

const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

/* ─────────────────────────────────────────
   Animation Variants
   ───────────────────────────────────────── */
const fadeInUp = {
  hidden: { opacity: 0, y: 30 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: 'easeOut' as const },
  },
};

const staggerContainer = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.15 },
  },
};

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
   Brand Logo
   ───────────────────────────────────────── */
export function BrandLogo({ size = 'md' }: { size?: 'sm' | 'md' }) {
  const height = size === 'sm' ? 32 : 40;
  const width = Math.round(height * 3.18);
  return (
    <Image
      src="/images/logo-horizontal.svg"
      alt="하루코토"
      width={width}
      height={height}
      className="shrink-0"
      priority
    />
  );
}

/* ─────────────────────────────────────────
   Animated Section (scroll-triggered)
   ───────────────────────────────────────── */
export function AnimatedSection({
  children,
  className,
  id,
  'aria-label': ariaLabel,
}: {
  children: React.ReactNode;
  className?: string;
  id?: string;
  'aria-label'?: string;
}) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });

  return (
    <motion.section
      ref={ref}
      id={id}
      aria-label={ariaLabel}
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
   Motion Wrappers (for server component usage)
   ───────────────────────────────────────── */
export function MotionDiv({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <motion.div variants={fadeInUp} className={className}>
      {children}
    </motion.div>
  );
}

export function MotionCard({
  href,
  children,
  className,
}: {
  href: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <motion.a
      href={href}
      variants={fadeInUp}
      whileHover={{ scale: 1.02, y: -4 }}
      transition={{ type: 'spring', stiffness: 300, damping: 20 }}
      className={className}
    >
      {children}
    </motion.a>
  );
}

/* ─────────────────────────────────────────
   Navigation Header
   ───────────────────────────────────────── */
export function Header() {
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
        <BrandLogo size="sm" />

        <nav
          className="hidden items-center gap-8 md:flex"
          aria-label="메인 네비게이션"
        >
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
            onClick={() => scrollTo('download')}
            className="text-muted-foreground hover:text-foreground text-sm font-medium transition-colors"
          >
            다운로드
          </button>
        </nav>

        <a
          href={APP_URL}
          className="bg-primary hover:bg-hk-primary-hover rounded-full px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:shadow-md"
        >
          시작하기
        </a>
      </div>
    </header>
  );
}

/* ─────────────────────────────────────────
   Hero Section
   ───────────────────────────────────────── */
export function Hero() {
  return (
    <section
      className="relative flex min-h-screen items-center overflow-hidden pt-20"
      aria-label="히어로"
    >
      <CherryBlossomStyles />
      <FloatingPetals />

      {/* Background decorative circles */}
      <div
        className="bg-primary/10 absolute -top-40 -right-40 h-[500px] w-[500px] rounded-full blur-3xl"
        aria-hidden="true"
      />
      <div
        className="bg-accent/30 absolute -bottom-20 -left-20 h-[400px] w-[400px] rounded-full blur-3xl"
        aria-hidden="true"
      />

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
                href={APP_URL}
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
                      <div className="text-muted-foreground text-[10px]">
                        연속 학습
                      </div>
                    </div>
                    <div className="bg-accent rounded-xl p-3">
                      <div className="text-foreground text-lg font-bold">
                        Lv.12
                      </div>
                      <div className="text-muted-foreground text-[10px]">
                        현재 레벨
                      </div>
                    </div>
                  </div>

                  {/* Today's word card */}
                  <div className="bg-secondary rounded-2xl p-4">
                    <div className="text-muted-foreground mb-2 text-[10px] font-medium">
                      오늘의 단어
                    </div>
                    <div className="font-jp text-foreground text-2xl font-bold">
                      桜
                    </div>
                    <div className="text-muted-foreground mt-0.5 text-xs">
                      さくら
                    </div>
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
              <div
                className="bg-primary/20 absolute -inset-4 -z-10 rounded-[3rem] blur-2xl"
                aria-hidden="true"
              />
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
