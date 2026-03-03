'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft,
  ChevronDown,
  BookmarkPlus,
  Check,
  RotateCcw,
  PartyPopper,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { apiFetch } from '@/lib/api';

type WrongEntry = {
  id: string;
  vocabularyId: string;
  word: string;
  reading: string;
  meaningKo: string;
  jlptLevel: string;
  exampleSentence: string | null;
  exampleTranslation: string | null;
  correctCount: number;
  incorrectCount: number;
  mastered: boolean;
  lastReviewedAt: string | null;
};

type WrongAnswersResponse = {
  entries: WrongEntry[];
  total: number;
  page: number;
  totalPages: number;
  summary: {
    totalWrong: number;
    mastered: number;
    remaining: number;
  };
};

export default function WrongAnswersPage() {
  const router = useRouter();
  const [data, setData] = useState<WrongAnswersResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [sort, setSort] = useState('most-wrong');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [savedWords, setSavedWords] = useState<Set<string>>(new Set());

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        page: String(page),
        sort,
        limit: '20',
      });
      const result = await apiFetch<WrongAnswersResponse>(
        `/api/v1/study/wrong-answers?${params.toString()}`
      );
      setData(result);
    } catch {
      // Silently ignore
    } finally {
      setLoading(false);
    }
  }, [page, sort]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  async function saveToWordbook(entry: WrongEntry) {
    if (savedWords.has(entry.vocabularyId)) return;
    try {
      const res = await fetch('/api/v1/wordbook', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          word: entry.word,
          reading: entry.reading,
          meaningKo: entry.meaningKo,
          source: 'QUIZ',
        }),
      });
      if (res.ok) {
        setSavedWords((prev) => new Set(prev).add(entry.vocabularyId));
      }
    } catch {
      // Silently ignore
    }
  }

  const sortOptions = [
    { value: 'most-wrong', label: '많이 틀린 순' },
    { value: 'recent', label: '최근 순' },
    { value: 'alphabetical', label: '가나다 순' },
  ];

  return (
    <div className="flex flex-col gap-4 p-4 pb-24">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button onClick={() => router.back()}>
          <ArrowLeft className="size-5" />
        </button>
        <h1 className="text-lg font-bold">오답 노트</h1>
      </div>

      {/* Summary */}
      {data && (
        <div className="grid grid-cols-3 gap-2">
          <Card>
            <CardContent className="flex flex-col items-center py-3">
              <span className="text-muted-foreground text-[10px]">전체</span>
              <span className="text-lg font-bold">
                {data.summary.totalWrong}
              </span>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex flex-col items-center py-3">
              <span className="text-muted-foreground text-[10px]">
                아직 학습중
              </span>
              <span className="text-hk-error text-lg font-bold">
                {data.summary.remaining}
              </span>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex flex-col items-center py-3">
              <span className="text-muted-foreground text-[10px]">
                극복 완료
              </span>
              <span className="text-primary text-lg font-bold">
                {data.summary.mastered}
              </span>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Review Button */}
      {data && data.summary.remaining > 0 && (
        <Button
          className="h-11 rounded-xl"
          onClick={() =>
            router.push('/study/quiz?type=VOCABULARY&level=N5&count=10&mode=review')
          }
        >
          <RotateCcw className="mr-2 size-4" />
          오답 복습 퀴즈 시작
        </Button>
      )}

      {/* Sort */}
      <div className="flex gap-1.5">
        {sortOptions.map((opt) => (
          <button
            key={opt.value}
            className={`rounded-full px-3 py-1.5 text-xs font-medium transition-colors ${
              sort === opt.value
                ? 'bg-primary text-primary-foreground'
                : 'bg-secondary text-muted-foreground'
            }`}
            onClick={() => {
              setSort(opt.value);
              setPage(1);
            }}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {/* List */}
      {loading ? (
        <div className="flex flex-col gap-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <div
              key={i}
              className="bg-secondary h-[72px] animate-pulse rounded-xl"
            />
          ))}
        </div>
      ) : data && data.entries.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16">
          <PartyPopper className="text-primary size-12" />
          <p className="text-muted-foreground text-sm">
            틀린 단어가 없어요! 완벽해요!
          </p>
          <Button
            variant="outline"
            size="sm"
            onClick={() => router.push('/study')}
          >
            학습으로 돌아가기
          </Button>
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {data?.entries.map((entry, i) => {
            const isExpanded = expandedId === entry.id;
            const total = entry.correctCount + entry.incorrectCount;
            const accuracy =
              total > 0
                ? Math.round((entry.correctCount / total) * 100)
                : 0;

            return (
              <motion.div
                key={entry.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.03 }}
              >
                <Card
                  className="cursor-pointer transition-colors"
                  onClick={() =>
                    setExpandedId(isExpanded ? null : entry.id)
                  }
                >
                  <CardContent className="flex flex-col gap-0 px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="bg-hk-error/10 flex size-8 items-center justify-center rounded-lg">
                        <span className="text-hk-error text-xs font-bold">
                          {entry.incorrectCount}
                        </span>
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <span className="font-jp truncate text-lg font-bold">
                            {entry.word}
                          </span>
                          <span className="font-jp text-muted-foreground shrink-0 text-sm">
                            {entry.reading}
                          </span>
                        </div>
                        <p className="text-muted-foreground truncate text-sm">
                          {entry.meaningKo}
                        </p>
                      </div>
                      <div className="flex shrink-0 items-center gap-1.5">
                        {entry.mastered ? (
                          <Badge
                            variant="ghost"
                            className="bg-primary/10 text-primary"
                          >
                            극복
                          </Badge>
                        ) : (
                          <Badge
                            variant="ghost"
                            className="bg-hk-error/10 text-hk-error"
                          >
                            학습중
                          </Badge>
                        )}
                        <ChevronDown
                          className={`text-muted-foreground size-4 transition-transform ${
                            isExpanded ? 'rotate-180' : ''
                          }`}
                        />
                      </div>
                    </div>

                    <AnimatePresence>
                      {isExpanded && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: 'auto', opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.2 }}
                          className="overflow-hidden"
                        >
                          <div className="mt-3 flex flex-col gap-2.5 border-t pt-3">
                            {/* Stats */}
                            <div className="grid grid-cols-3 gap-2">
                              <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                                <span className="text-muted-foreground text-xs">
                                  오답
                                </span>
                                <span className="text-hk-error text-sm font-bold">
                                  {entry.incorrectCount}회
                                </span>
                              </div>
                              <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                                <span className="text-muted-foreground text-xs">
                                  정답률
                                </span>
                                <span className="text-sm font-bold">
                                  {accuracy}%
                                </span>
                              </div>
                              <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                                <span className="text-muted-foreground text-xs">
                                  총 풀이
                                </span>
                                <span className="text-sm font-bold">
                                  {total}회
                                </span>
                              </div>
                            </div>

                            {/* Example */}
                            {entry.exampleSentence && (
                              <div className="bg-secondary rounded-lg px-3 py-2">
                                <p className="font-jp text-sm">
                                  {entry.exampleSentence}
                                </p>
                                {entry.exampleTranslation && (
                                  <p className="text-muted-foreground mt-0.5 text-xs">
                                    {entry.exampleTranslation}
                                  </p>
                                )}
                              </div>
                            )}

                            {/* Actions */}
                            <div className="flex items-center gap-2">
                              <Badge variant="outline" className="text-[10px]">
                                {entry.jlptLevel}
                              </Badge>
                              <button
                                className={`ml-auto flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium transition-colors ${
                                  savedWords.has(entry.vocabularyId)
                                    ? 'bg-primary/10 text-primary'
                                    : 'bg-secondary text-muted-foreground'
                                }`}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  saveToWordbook(entry);
                                }}
                                disabled={savedWords.has(entry.vocabularyId)}
                              >
                                {savedWords.has(entry.vocabularyId) ? (
                                  <>
                                    <Check className="size-3" />
                                    저장됨
                                  </>
                                ) : (
                                  <>
                                    <BookmarkPlus className="size-3" />
                                    단어장에 추가
                                  </>
                                )}
                              </button>
                            </div>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </CardContent>
                </Card>
              </motion.div>
            );
          })}

          {/* Pagination */}
          {data && data.totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 pt-2">
              <Button
                variant="outline"
                size="sm"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                이전
              </Button>
              <span className="text-muted-foreground text-sm">
                {page} / {data.totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                disabled={page >= data.totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                다음
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
