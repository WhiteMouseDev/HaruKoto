'use client';

import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { useSavedQuizzes } from '@/hooks/use-saved-quizzes';

export function SavedQuizResumeCard() {
  const query = useSavedQuizzes();
  const session = query.data?.pages[0]?.sessions[0];
  return (
    <section className="bg-card rounded-2xl border p-5">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-semibold">이어서 학습하기</h2>
        <Link href="/study/saved-quizzes" className="text-primary text-sm">
          전체 보기
        </Link>
      </div>
      {query.isLoading && (
        <p role="status" className="text-muted-foreground mt-3 text-sm">
          저장된 퀴즈를 불러오고 있어요.
        </p>
      )}
      {query.isError && (
        <div role="alert" className="mt-3 text-sm">
          <p>목록을 불러오지 못했어요. 저장된 기록은 유지됩니다.</p>
          <Button
            variant="outline"
            size="sm"
            className="mt-2"
            onClick={() => query.refetch()}
          >
            다시 시도
          </Button>
        </div>
      )}
      {session && (
        <div className="mt-3 flex flex-col gap-3">
          <p className="text-muted-foreground text-xs">
            최근 시작한 퀴즈 · {session.jlptLevel} ·{' '}
            {new Date(session.startedAt).toLocaleDateString('ko-KR', {
              timeZone: 'Asia/Seoul',
            })}
          </p>
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
            <>
              <p className="text-muted-foreground text-sm">
                이 퀴즈의 저장 정보를 확인해 주세요. 다른 저장 퀴즈도 선택할 수
                있어요.
              </p>
              <Button variant="outline" asChild>
                <Link href="/study/saved-quizzes">저장된 퀴즈 확인하기</Link>
              </Button>
            </>
          )}
        </div>
      )}
      {!session && !query.isLoading && !query.isError && (
        <p className="text-muted-foreground mt-3 text-sm">
          한 문항 이상 저장한 퀴즈를 여기서 이어 풀 수 있어요.
        </p>
      )}
    </section>
  );
}
