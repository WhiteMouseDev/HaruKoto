'use client';

import { useState, useEffect } from 'react';
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
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

const JLPT_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;

type IncompleteSession = {
  id: string;
  quizType: string;
  jlptLevel: string;
  totalQuestions: number;
  answeredCount: number;
  correctCount: number;
  startedAt: string;
};

type StudyStats = {
  totalCount: number;
  studiedCount: number;
  progress: number;
};

export default function StudyPage() {
  const router = useRouter();
  const [selectedLevel, setSelectedLevel] = useState<string>('N5');
  const [selectedTab, setSelectedTab] = useState('VOCABULARY');
  const [incompleteSession, setIncompleteSession] =
    useState<IncompleteSession | null>(null);
  const [stats, setStats] = useState<StudyStats | null>(null);

  useEffect(() => {
    async function checkIncomplete() {
      try {
        const res = await fetch('/api/v1/quiz/incomplete');
        const data = await res.json();
        if (data.session) {
          setIncompleteSession(data.session);
        }
      } catch {
        // Silently ignore
      }
    }
    checkIncomplete();
  }, []);

  useEffect(() => {
    async function fetchStats() {
      try {
        const res = await fetch(
          `/api/v1/quiz/stats?level=${selectedLevel}&type=${selectedTab}`
        );
        const data = await res.json();
        setStats(data);
      } catch {
        // Silently ignore
      }
    }
    fetchStats();
  }, [selectedLevel, selectedTab]);

  function startQuiz() {
    router.push(
      `/study/quiz?type=${selectedTab}&level=${selectedLevel}&count=10`
    );
  }

  return (
    <div className="flex flex-col gap-5 p-4">
      {/* Resume Banner */}
      {incompleteSession && (
        <Card className="border-amber-200 bg-amber-50 dark:border-amber-900 dark:bg-amber-950/30">
          <CardContent className="flex flex-col gap-3 p-4">
            <div className="flex items-center gap-2">
              <PenLine className="size-5 shrink-0" />
              <div className="flex-1">
                <p className="text-sm font-semibold">
                  진행 중인 퀴즈가 있어요
                </p>
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
                className="flex-1"
                onClick={() => {
                  router.push(
                    `/study/quiz?type=${incompleteSession.quizType}&level=${incompleteSession.jlptLevel}&count=${incompleteSession.totalQuestions}`
                  );
                }}
              >
                새로 시작
              </Button>
              <Button
                size="sm"
                className="flex-1"
                onClick={() => {
                  router.push(
                    `/study/quiz?resume=${incompleteSession.id}`
                  );
                }}
              >
                이어서 풀기
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Header */}
      <h1 className="pt-2 text-2xl font-bold">JLPT 학습</h1>

      {/* Level Selector */}
      <div className="flex gap-2">
        {JLPT_LEVELS.map((level) => (
          <button
            key={level}
            className={`flex-1 rounded-xl border-2 py-2.5 text-sm font-bold transition-all ${
              selectedLevel === level
                ? 'border-primary bg-primary/10 text-primary'
                : 'border-border text-muted-foreground'
            } ${level !== 'N5' && level !== 'N4' ? 'opacity-40' : ''}`}
            onClick={() =>
              (level === 'N5' || level === 'N4') && setSelectedLevel(level)
            }
            disabled={level !== 'N5' && level !== 'N4'}
          >
            {level}
          </button>
        ))}
      </div>

      {/* Quiz Type Tabs */}
      <Tabs value={selectedTab} onValueChange={setSelectedTab}>
        <TabsList className="w-full">
          <TabsTrigger value="VOCABULARY" className="flex-1">
            단어
          </TabsTrigger>
          <TabsTrigger value="GRAMMAR" className="flex-1">
            문법
          </TabsTrigger>
          <TabsTrigger value="KANJI" className="flex-1" disabled>
            한자
          </TabsTrigger>
          <TabsTrigger value="LISTENING" className="flex-1" disabled>
            청해
          </TabsTrigger>
        </TabsList>
      </Tabs>

      {/* Study Card */}
      <Card>
        <CardContent className="flex flex-col gap-4 p-5">
          <div className="flex items-center gap-3">
            <div className="bg-primary/10 flex size-10 items-center justify-center rounded-xl">
              {selectedTab === 'VOCABULARY' ? (
                <BookOpen className="text-primary size-5" />
              ) : (
                <Languages className="text-primary size-5" />
              )}
            </div>
            <div className="flex-1">
              <h3 className="font-semibold">
                {selectedLevel} {selectedTab === 'VOCABULARY' ? '단어' : '문법'}{' '}
                학습
              </h3>
              <p className="text-muted-foreground text-sm">
                {stats
                  ? `${stats.totalCount}개 ${selectedTab === 'VOCABULARY' ? '단어' : '문법'} · 4지선다`
                  : `${selectedTab === 'VOCABULARY' ? '단어' : '문법'} · 4지선다`}
              </p>
            </div>
            <Badge variant="secondary">10문제</Badge>
          </div>

          <div className="flex flex-col gap-1.5">
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

          <Button className="h-12 rounded-xl text-base" onClick={startQuiz}>
            학습 시작하기
            <Flower2 className="ml-1.5 size-4" />
          </Button>
        </CardContent>
      </Card>

      {/* My Study Data */}
      <div className="flex flex-col gap-2">
        <h2 className="font-semibold">내 학습 데이터</h2>
        {[
          {
            icon: FileX,
            label: '오답 노트',
            href: '/study/quiz?type=VOCABULARY&level=N5&count=10&mode=review',
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
        ].map((item) => (
          <Card
            key={item.label}
            className={
              item.disabled ? 'cursor-default opacity-50' : 'cursor-pointer'
            }
            onClick={() => !item.disabled && router.push(item.href)}
          >
            <CardContent className="flex items-center gap-3 px-4 py-3">
              <item.icon className="text-muted-foreground size-4" />
              <span className="flex-1 text-sm">{item.label}</span>
              {item.disabled ? (
                <Badge variant="outline" className="text-[10px]">
                  준비 중
                </Badge>
              ) : (
                <ChevronRight className="text-muted-foreground size-4" />
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
