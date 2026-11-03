'use client';

import Link from 'next/link';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { useSavedQuizzes } from '@/hooks/use-saved-quizzes';

const typeLabels: Record<string, string> = {
  VOCABULARY: '단어',
  GRAMMAR: '문법',
  KANJI: '한자',
  LISTENING: '듣기',
  CLOZE: '빈칸',
  SENTENCE_ARRANGE: '문장 배열',
};
const modeLabels: Record<string, string> = {
  normal: '선택형',
  matching: '매칭',
  arrange: '문장 배열',
  typing: '쓰기',
  cloze: '빈칸',
  review: '복습',
  smart: '맞춤 퀴즈',
  wrong_answer_review: '오답 복습',
};

export default function SavedQuizzesPage() {
  const [level, setLevel] = useState('');
  const [type, setType] = useState('');
  const query = useSavedQuizzes({
    ...(level ? { jlptLevel: level } : {}),
    ...(type ? { quizType: type } : {}),
  });
  const sessions = query.data?.pages.flatMap((page) => page.sessions) ?? [];
  return (
    <main className="flex flex-col gap-5 px-6 py-6">
      <Link href="/study" className="text-muted-foreground text-sm">
        ← 학습으로 돌아가기
      </Link>
      <div>
        <h1 className="text-2xl font-bold">저장된 퀴즈</h1>
        <p className="text-muted-foreground mt-1 text-sm">
          최근 시작 순 · 저장한 답안부터 이어 풀어요.
        </p>
      </div>
      <div className="flex gap-3">
        <label className="flex-1 text-sm">
          레벨
          <select
            className="bg-card mt-1 w-full rounded-lg border p-2"
            value={level}
            onChange={(event) => setLevel(event.target.value)}
          >
            <option value="">모든 레벨</option>
            {['N5', 'N4', 'N3', 'N2', 'N1'].map((value) => (
              <option key={value}>{value}</option>
            ))}
          </select>
        </label>
        <label className="flex-1 text-sm">
          유형
          <select
            className="bg-card mt-1 w-full rounded-lg border p-2"
            value={type}
            onChange={(event) => setType(event.target.value)}
          >
            <option value="">모든 유형</option>
            {Object.entries(typeLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </div>
      {query.isLoading && <p role="status">저장된 퀴즈를 불러오고 있어요.</p>}
      {query.isError && (
        <div role="alert" className="rounded-xl border p-4">
          <p>목록을 불러오지 못했어요. 저장된 기록은 유지됩니다.</p>
          <Button
            variant="outline"
            className="mt-3"
            onClick={() => query.refetch()}
          >
            다시 시도
          </Button>
        </div>
      )}
      {!query.isLoading && !query.isError && sessions.length === 0 && (
        <div className="rounded-xl border p-4">
          <p>이 조건에 저장된 퀴즈가 없어요.</p>
          {(level || type) && (
            <Button
              variant="outline"
              className="mt-3"
              onClick={() => {
                setLevel('');
                setType('');
              }}
            >
              전체 기록 보기
            </Button>
          )}
        </div>
      )}
      {sessions.map((session) => (
        <article
          key={session.id}
          className="bg-card flex flex-col gap-3 rounded-2xl border p-5"
        >
          <div>
            <h2 className="font-semibold">
              {session.jlptLevel} {typeLabels[session.quizType] ?? '퀴즈'}
              {session.mode
                ? ` · ${modeLabels[session.mode] ?? '저장 퀴즈'}`
                : ''}
            </h2>
            <p className="text-muted-foreground mt-1 text-xs">
              {new Date(session.startedAt).toLocaleDateString('ko-KR', {
                timeZone: 'Asia/Seoul',
              })}{' '}
              시작
            </p>
          </div>
          {session.resumeStatus === 'available' ? (
            <>
              <p className="text-sm">
                {session.answeredCount}/{session.totalQuestions}문제 저장됨
              </p>
              <Button asChild>
                <Link
                  href={`/study/quiz?resume=${encodeURIComponent(session.id)}`}
                >
                  {session.remainingCount === 0
                    ? '결과 확인하기'
                    : '이어서 풀기'}
                </Link>
              </Button>
            </>
          ) : (
            <p className="text-muted-foreground text-sm">
              {session.resumeReason === 'UNSUPPORTED_CLIENT'
                ? '이 퀴즈는 앱에서 이어서 학습해 주세요.'
                : '이 기록을 여기서 안전하게 이어 풀 수 없어요.'}{' '}
              저장된 학습 기록은 유지됩니다.
            </p>
          )}
        </article>
      ))}
      {query.hasNextPage && (
        <Button
          variant="outline"
          disabled={query.isFetchingNextPage}
          onClick={() => query.fetchNextPage()}
        >
          {query.isFetchingNextPage ? '불러오는 중…' : '더 보기'}
        </Button>
      )}
    </main>
  );
}
