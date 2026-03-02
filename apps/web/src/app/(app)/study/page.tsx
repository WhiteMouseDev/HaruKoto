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
  Heart,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

const JLPT_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;

export default function StudyPage() {
  const router = useRouter();
  const [selectedLevel, setSelectedLevel] = useState<string>('N5');
  const [selectedTab, setSelectedTab] = useState('VOCABULARY');

  function startQuiz() {
    router.push(
      `/study/quiz?type=${selectedTab}&level=${selectedLevel}&count=10`
    );
  }

  return (
    <div className="flex flex-col gap-5 p-4">
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
            } ${level !== 'N5' ? 'opacity-40' : ''}`}
            onClick={() => level === 'N5' && setSelectedLevel(level)}
            disabled={level !== 'N5'}
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
                {selectedTab === 'VOCABULARY'
                  ? '200개 단어 · 4지선다'
                  : '30개 문법 · 4지선다'}
              </p>
            </div>
            <Badge variant="secondary">10문제</Badge>
          </div>

          <div className="flex flex-col gap-1.5">
            <div className="text-muted-foreground flex justify-between text-xs">
              <span>학습 진행률</span>
              <span>0%</span>
            </div>
            <div className="bg-secondary h-2 overflow-hidden rounded-full">
              <div className="bg-primary h-full w-0 rounded-full transition-all" />
            </div>
          </div>

          <Button className="h-12 rounded-xl text-base" onClick={startQuiz}>
            학습 시작하기 🌸
          </Button>
        </CardContent>
      </Card>

      {/* My Study Data */}
      <div className="flex flex-col gap-2">
        <h2 className="font-semibold">내 학습 데이터</h2>
        {[
          { icon: Heart, label: '좋아하는 단어', href: '#' },
          { icon: FileX, label: '오답 노트', href: '#' },
          { icon: Notebook, label: '내가 학습한 단어', href: '#' },
          { icon: BookMarked, label: '내 단어장', href: '#' },
        ].map((item) => (
          <Card key={item.label}>
            <CardContent className="flex items-center gap-3 px-4 py-3">
              <item.icon className="text-muted-foreground size-4" />
              <span className="flex-1 text-sm">{item.label}</span>
              <ChevronRight className="text-muted-foreground size-4" />
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
