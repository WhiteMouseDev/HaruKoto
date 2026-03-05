'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
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
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { KanaProgressBanner } from '@/components/features/kana/kana-progress-banner';
import { useKanaProgress } from '@/hooks/use-kana';
import { useIncompleteQuiz, useQuizStats } from '@/hooks/use-quiz';

const JLPT_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;

const QUIZ_TYPES = [
  { value: 'VOCABULARY', label: '단어', disabled: false },
  { value: 'GRAMMAR', label: '문법', disabled: false },
  { value: 'KANJI', label: '한자', disabled: true },
  { value: 'LISTENING', label: '청해', disabled: true },
] as const;

export default function StudyPage() {
  const router = useRouter();
  const { data: kanaProgress } = useKanaProgress();
  const [selectedLevel, setSelectedLevel] = useState<string>('N5');
  const [selectedTab, setSelectedTab] = useState('VOCABULARY');

  const { data: incompleteData } = useIncompleteQuiz();
  const incompleteSession = incompleteData?.session ?? null;

  const { data: stats } = useQuizStats(selectedLevel, selectedTab);

  function startQuiz() {
    router.push(
      `/study/quiz?type=${selectedTab}&level=${selectedLevel}&count=10`
    );
  }

  return (
    <div className="flex flex-col gap-5 px-6 pt-6 pb-6">
      {/* Resume Banner */}
      {incompleteSession && (
        <div className="overflow-hidden rounded-3xl border border-amber-200 bg-amber-50 p-5 shadow-sm dark:border-amber-900 dark:bg-amber-950/30">
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
        </div>
      )}

      {/* Kana Progress Banner */}
      {kanaProgress &&
        (kanaProgress.hiragana.pct < 100 ||
          kanaProgress.katakana.pct < 100) && (
          <KanaProgressBanner
            hiragana={kanaProgress.hiragana}
            katakana={kanaProgress.katakana}
          />
        )}

      {/* Header */}
      <h1 className="pt-2 text-2xl font-bold">JLPT 학습</h1>

      {/* Level Selector */}
      <div className="flex gap-2">
        {JLPT_LEVELS.map((level) => {
          const isActive = selectedLevel === level;
          const isAvailable = level === 'N5' || level === 'N4';
          return (
            <button
              key={level}
              className={`flex-1 rounded-2xl border-2 py-2.5 text-sm font-bold transition-all ${
                isActive
                  ? 'border-primary bg-primary/10 text-primary'
                  : 'border-border text-muted-foreground'
              } ${!isAvailable ? 'opacity-40' : ''}`}
              onClick={() => isAvailable && setSelectedLevel(level)}
              disabled={!isAvailable}
            >
              {level}
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
              } ${type.disabled ? 'opacity-40' : ''}`}
              onClick={() => !type.disabled && setSelectedTab(type.value)}
              disabled={type.disabled}
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
                ? `${stats.totalCount}개 ${selectedTab === 'VOCABULARY' ? '단어' : '문법'} · 4지선다`
                : `${selectedTab === 'VOCABULARY' ? '단어' : '문법'} · 4지선다`}
            </p>
          </div>
          <Badge variant="secondary">10문제</Badge>
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

        <Button
          className="h-12 w-full text-base"
          onClick={startQuiz}
        >
          학습 시작하기
          <Flower2 className="ml-1.5 size-4" />
        </Button>
      </div>

      {/* My Study Data */}
      <div className="flex flex-col gap-3">
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
        ].map((item) => (
          <div
            key={item.label}
            className={`flex items-center gap-3 rounded-2xl border border-border bg-card px-4 py-3.5 shadow-sm transition-colors ${
              item.disabled
                ? 'cursor-default opacity-50'
                : 'cursor-pointer hover:bg-secondary'
            }`}
            onClick={() => !item.disabled && router.push(item.href)}
          >
            <item.icon className="text-muted-foreground size-4" />
            <span className="flex-1 text-sm font-medium">{item.label}</span>
            {item.disabled ? (
              <Badge variant="outline" className="text-[10px]">
                준비 중
              </Badge>
            ) : (
              <ChevronRight className="text-muted-foreground size-4" />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
