'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import {
  BookOpen,
  Languages,
  ChevronRight,
  FileX,
  BookMarked,
  Notebook,
  PenLine,
  Flower2,
  Grid3x3,
  PlayCircle,
  RotateCcw,
  Link2,
  TextCursorInput,
  ArrowUpDown,
  Keyboard,
  RefreshCw,
  Flame,
  Library,
} from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { KanaProgressBanner } from '@/components/features/kana/kana-progress-banner';
import { useKanaProgress } from '@/hooks/use-kana';
import { useDashboard } from '@/hooks/use-dashboard';
import {
  useIncompleteQuiz,
  useQuizStats,
  useRecommendations,
} from '@/hooks/use-quiz';

const JLPT_LEVELS = [
  { value: 'N5', available: true },
  { value: 'N4', available: true },
  { value: 'N3', available: true },
  { value: 'N2', available: true },
  { value: 'N1', available: true },
] as const;

const QUIZ_TYPES = [
  { value: 'VOCABULARY', label: '단어' },
  { value: 'GRAMMAR', label: '문법' },
] as const;

const QUIZ_MODES = [
  { mode: 'normal' as const, icon: BookOpen, label: '4지선다' },
  { mode: 'matching' as const, icon: Link2, label: '매칭' },
  { mode: 'cloze' as const, icon: TextCursorInput, label: '빈칸' },
  { mode: 'arrange' as const, icon: ArrowUpDown, label: '어순' },
  { mode: 'typing' as const, icon: Keyboard, label: '쓰기' },
] as const;

type StudyTab = 'recommend' | 'free';

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.4 } },
};

export default function StudyPage() {
  const router = useRouter();
  const { data: kanaProgress } = useKanaProgress();
  const { data: dashboard } = useDashboard();
  const [studyTab, setStudyTab] = useState<StudyTab>('recommend');
  const [selectedLevel, setSelectedLevel] = useState<string>('N5');
  const [selectedTab, setSelectedTab] = useState('VOCABULARY');
  const [quizMode, setQuizMode] = useState<
    'normal' | 'matching' | 'cloze' | 'arrange' | 'typing'
  >('normal');

  const { data: incompleteData } = useIncompleteQuiz();
  const incompleteSession = incompleteData?.session ?? null;

  const { data: stats } = useQuizStats(selectedLevel, selectedTab);
  const {
    data: recommendations,
    isLoading: recsLoading,
    isError: recsError,
    refetch: refetchRecs,
  } = useRecommendations();

  const isLoading = recsLoading && !recommendations;

  function startQuiz() {
    const modeParam =
      quizMode === 'matching'
        ? '&mode=matching'
        : quizMode === 'cloze'
          ? '&mode=cloze'
          : quizMode === 'arrange'
            ? '&mode=arrange'
            : quizMode === 'typing'
              ? '&mode=typing'
              : '';
    router.push(
      `/study/quiz?type=${selectedTab}&level=${selectedLevel}&count=10${modeParam}`
    );
  }

  function getLastReviewText() {
    if (!recommendations?.lastReviewedAt) return null;
    const last = new Date(recommendations.lastReviewedAt);
    const now = new Date();
    const diffDays = Math.floor(
      (now.getTime() - last.getTime()) / (1000 * 60 * 60 * 24)
    );
    if (diffDays === 0) return '오늘';
    if (diffDays === 1) return '어제';
    return `${diffDays}일 전`;
  }

  const modeLabel =
    quizMode === 'matching'
      ? '매칭'
      : quizMode === 'cloze'
        ? '빈칸 채우기'
        : quizMode === 'arrange'
          ? '어순 배열'
          : quizMode === 'typing'
            ? '단어 쓰기'
            : '4지선다';

  if (isLoading) {
    return (
      <div aria-busy="true" className="flex flex-col gap-5 px-6 pt-6 pb-6">
        <div className="bg-secondary h-8 w-32 rounded-lg animate-pulse" />
        <div className="bg-secondary h-12 rounded-2xl animate-pulse" />
        {[1, 2, 3].map((n) => (
          <div key={n} className="bg-secondary h-28 rounded-3xl animate-pulse" />
        ))}
        <div className="bg-secondary h-6 w-28 rounded-lg animate-pulse" />
        {[1, 2, 3, 4].map((n) => (
          <div key={n} className="bg-secondary h-12 rounded-2xl animate-pulse" />
        ))}
      </div>
    );
  }

  return (
    <motion.div
      className="flex flex-col gap-5 px-6 pt-6 pb-6"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Resume Banner */}
      {incompleteSession && (
        <motion.div variants={item} className="overflow-hidden rounded-3xl border border-amber-200 bg-amber-50 p-5 shadow-sm dark:border-amber-900 dark:bg-amber-950/30">
          <div className="mb-4 flex items-center gap-3">
            <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/30">
              <PenLine className="size-5 text-amber-600 dark:text-amber-400" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-bold">진행 중인 퀴즈가 있어요</p>
              <p className="text-muted-foreground text-xs">
                {incompleteSession.jlptLevel}{' '}
                {incompleteSession.quizType === 'VOCABULARY'
                  ? '단어'
                  : '문법'}{' '}
                · {incompleteSession.answeredCount}/
                {incompleteSession.totalQuestions} 문제
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              className="h-10 flex-1 gap-1.5 bg-white dark:bg-transparent"
              onClick={() => {
                router.push(
                  `/study/quiz?type=${incompleteSession.quizType}&level=${incompleteSession.jlptLevel}&count=${incompleteSession.totalQuestions}`
                );
              }}
            >
              <RotateCcw className="size-3.5" />
              새로 시작
            </Button>
            <Button
              size="sm"
              className="h-10 flex-1 gap-1.5"
              onClick={() => {
                router.push(
                  `/study/quiz?resume=${incompleteSession.id}`
                );
              }}
            >
              <PlayCircle className="size-3.5" />
              이어서 풀기
            </Button>
          </div>
        </motion.div>
      )}

      {/* Kana Progress Banner */}
      {dashboard?.showKana &&
        kanaProgress &&
        (kanaProgress.hiragana.pct < 100 ||
          kanaProgress.katakana.pct < 100) && (
          <KanaProgressBanner
            hiragana={kanaProgress.hiragana}
            katakana={kanaProgress.katakana}
          />
        )}

      {/* Header */}
      <motion.h1 variants={item} className="pt-2 text-2xl font-bold">JLPT 학습</motion.h1>

      {/* Study Tab Switcher */}
      <motion.div variants={item} className="flex gap-1 rounded-2xl bg-secondary p-1">
        <button
          className={`flex flex-1 items-center justify-center gap-1.5 rounded-xl py-2.5 text-sm font-medium transition-all ${
            studyTab === 'recommend'
              ? 'bg-card text-foreground shadow-sm'
              : 'text-muted-foreground'
          }`}
          onClick={() => setStudyTab('recommend')}
        >
          <Flame className="size-3.5" />
          추천
        </button>
        <button
          className={`flex flex-1 items-center justify-center gap-1.5 rounded-xl py-2.5 text-sm font-medium transition-all ${
            studyTab === 'free'
              ? 'bg-card text-foreground shadow-sm'
              : 'text-muted-foreground'
          }`}
          onClick={() => setStudyTab('free')}
        >
          <Library className="size-3.5" />
          자율
        </button>
      </motion.div>

      {/* Recommend Tab */}
      {studyTab === 'recommend' && (
        <motion.div variants={item} className="flex flex-col gap-3">
          {/* Error state */}
          {recsError && (
            <div className="flex flex-col items-center justify-center gap-4 rounded-3xl border bg-card p-8">
              <p className="text-muted-foreground text-center">추천을 불러올 수 없습니다</p>
              <Button variant="outline" onClick={() => refetchRecs()} className="gap-2">
                <RefreshCw className="size-4" />
                다시 시도
              </Button>
            </div>
          )}

          {/* Review due */}
          {recommendations && recommendations.reviewDueCount > 0 && (
            <div
              className="from-primary/5 to-primary/10 border-primary/30 cursor-pointer rounded-3xl border bg-gradient-to-r p-5 shadow-sm transition-colors hover:from-primary/10 hover:to-primary/15"
              onClick={() =>
                router.push(
                  `/study/quiz?type=VOCABULARY&level=N5&count=10&mode=review`
                )
              }
            >
              <div className="mb-2 flex items-center gap-2">
                <RefreshCw className="text-primary size-5" />
                <span className="font-bold">복습할 단어</span>
              </div>
              <p className="text-muted-foreground text-sm">
                오늘 복습이 필요한 단어{' '}
                <span className="text-primary font-semibold">
                  {recommendations.reviewDueCount}개
                </span>
                가 있어요
              </p>
              {getLastReviewText() && (
                <p className="text-muted-foreground mt-1 text-xs">
                  마지막 복습: {getLastReviewText()}
                </p>
              )}
              <p className="text-primary mt-3 text-sm font-medium">
                지금 복습하기 →
              </p>
            </div>
          )}

          {/* New words */}
          {recommendations && recommendations.newWordsCount > 0 && (
            <div
              className="cursor-pointer rounded-3xl border bg-card p-5 shadow-sm transition-colors hover:bg-secondary/50"
              onClick={() =>
                router.push(
                  `/study/quiz?type=VOCABULARY&level=N5&count=10`
                )
              }
            >
              <div className="mb-2 flex items-center gap-2">
                <BookOpen className="text-primary size-5" />
                <span className="font-bold">새로운 N5 단어</span>
              </div>
              <p className="text-muted-foreground text-sm">
                아직 안 본 단어 {recommendations.newWordsCount}개
              </p>
              <p className="text-primary mt-3 text-sm font-medium">
                학습 시작 →
              </p>
            </div>
          )}

          {/* Wrong answers */}
          {recommendations && recommendations.wrongCount > 0 && (
            <div
              className="cursor-pointer rounded-3xl border bg-card p-5 shadow-sm transition-colors hover:bg-secondary/50"
              onClick={() => router.push('/study/wrong-answers')}
            >
              <div className="mb-2 flex items-center gap-2">
                <FileX className="text-hk-error size-5" />
                <span className="font-bold">오답 노트</span>
              </div>
              <p className="text-muted-foreground text-sm">
                최근 틀린 단어 {recommendations.wrongCount}개
              </p>
              <p className="text-primary mt-3 text-sm font-medium">
                오답 복습 →
              </p>
            </div>
          )}

          {/* Empty state */}
          {recommendations &&
            recommendations.reviewDueCount === 0 &&
            recommendations.newWordsCount === 0 &&
            recommendations.wrongCount === 0 && (
              <div className="flex flex-col items-center gap-2 rounded-3xl border bg-card p-8">
                <Flower2 className="text-primary size-8" />
                <p className="font-semibold">추천 학습이 없어요</p>
                <p className="text-muted-foreground text-center text-sm">
                  자율 탭에서 원하는 학습을 시작해보세요
                </p>
              </div>
            )}
        </motion.div>
      )}

      {/* Free Tab */}
      {studyTab === 'free' && (
        <>
          {/* Level Selector */}
          <div className="flex gap-2">
            {JLPT_LEVELS.map((level) => {
              const isActive = selectedLevel === level.value;
              const isAvailable = level.available;

              return (
                <button
                  key={level.value}
                  className={`relative flex-1 rounded-2xl border-2 py-2.5 text-sm font-bold transition-all ${
                    isActive
                      ? 'border-primary bg-primary/10 text-primary'
                      : isAvailable
                        ? 'border-border text-muted-foreground'
                        : 'border-border/50 text-muted-foreground/40'
                  }`}
                  onClick={() => {
                    if (isAvailable) {
                      setSelectedLevel(level.value);
                    } else {
                      toast('곧 추가 예정이에요!', {
                        description: `${level.value} 콘텐츠를 열심히 준비하고 있어요`,
                      });
                    }
                  }}
                >
                  {level.value}
                  {!isAvailable && (
                    <span className="absolute -top-2 -right-1 rounded-full bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground">
                      곧 추가
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          {/* Quiz Type Selector */}
          <div className="flex gap-1 rounded-2xl bg-secondary p-1">
            {QUIZ_TYPES.map((type) => {
              const isActive = selectedTab === type.value;
              return (
                <button
                  key={type.value}
                  className={`flex-1 rounded-xl py-2 text-sm font-medium transition-all ${
                    isActive
                      ? 'bg-card text-foreground shadow-sm'
                      : 'text-muted-foreground'
                  }`}
                  onClick={() => setSelectedTab(type.value)}
                >
                  {type.label}
                </button>
              );
            })}
          </div>

          {/* Study Card */}
          <div className="rounded-3xl border border-border bg-card p-5 shadow-sm">
            <div className="mb-4 flex items-center gap-3">
              <div className="bg-primary/10 flex size-10 items-center justify-center rounded-xl">
                {selectedTab === 'VOCABULARY' ? (
                  <BookOpen className="text-primary size-5" />
                ) : (
                  <Languages className="text-primary size-5" />
                )}
              </div>
              <div className="flex-1">
                <h3 className="font-bold">
                  {selectedLevel}{' '}
                  {selectedTab === 'VOCABULARY' ? '단어' : '문법'} 학습
                </h3>
                <p className="text-muted-foreground text-sm">
                  {stats
                    ? `${stats.totalCount}개 ${selectedTab === 'VOCABULARY' ? '단어' : '문법'} · ${modeLabel}`
                    : `${selectedTab === 'VOCABULARY' ? '단어' : '문법'} · ${modeLabel}`}
                </p>
              </div>
              <Badge variant="secondary">10문제</Badge>
            </div>

            {/* Quiz Mode Selector */}
            <div className="mb-4 flex flex-wrap gap-2">
              {QUIZ_MODES.map(({ mode, icon: Icon, label }) => (
                <button
                  key={mode}
                  className={`flex flex-1 basis-[calc(33%-0.5rem)] items-center justify-center gap-1.5 rounded-xl border-2 py-2.5 text-sm font-medium transition-all ${
                    quizMode === mode
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border text-muted-foreground'
                  }`}
                  onClick={() => setQuizMode(mode)}
                >
                  <Icon className="size-3.5" />
                  {label}
                </button>
              ))}
            </div>

            <div className="mb-4 flex flex-col gap-1.5">
              <div className="text-muted-foreground flex justify-between text-xs">
                <span>학습 진행률</span>
                <span>{stats ? `${stats.progress}%` : '0%'}</span>
              </div>
              <div className="bg-secondary h-2 overflow-hidden rounded-full">
                <div
                  className="bg-primary h-full rounded-full transition-all"
                  style={{ width: `${stats?.progress ?? 0}%` }}
                />
              </div>
            </div>

            <Button className="h-12 w-full text-base" onClick={startQuiz}>
              학습 시작하기
              <Flower2 className="ml-1.5 size-4" />
            </Button>
          </div>
        </>
      )}

      {/* My Study Data */}
      <motion.div variants={item} className="flex flex-col gap-3">
        <h2 className="font-bold">내 학습 데이터</h2>
        {[
          {
            icon: FileX,
            label: '오답 노트',
            href: '/study/wrong-answers',
            disabled: false,
          },
          {
            icon: Notebook,
            label: '내가 학습한 단어',
            href: '/study/learned-words',
            disabled: false,
          },
          {
            icon: BookMarked,
            label: '내 단어장',
            href: '/study/wordbook',
            disabled: false,
          },
          {
            icon: Grid3x3,
            label: '50음도 차트',
            href: '/study/kana/chart',
            disabled: false,
          },
        ].map((link) => (
          <div
            key={link.label}
            className={`flex items-center gap-3 rounded-2xl border border-border bg-card px-4 py-3.5 shadow-sm transition-colors ${
              link.disabled
                ? 'cursor-default opacity-50'
                : 'cursor-pointer hover:bg-secondary'
            }`}
            onClick={() => !link.disabled && router.push(link.href)}
          >
            <link.icon className="text-muted-foreground size-4" />
            <span className="flex-1 text-sm font-medium">{link.label}</span>
            {link.disabled ? (
              <Badge variant="outline" className="text-[10px]">
                준비 중
              </Badge>
            ) : (
              <ChevronRight className="text-muted-foreground size-4" />
            )}
          </div>
        ))}
      </motion.div>
    </motion.div>
  );
}
