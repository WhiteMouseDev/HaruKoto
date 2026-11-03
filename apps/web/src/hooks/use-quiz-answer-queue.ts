'use client';

import { useEffect, useState } from 'react';
import {
  QuizAnswerQueue,
  type AnswerQueueState,
} from '@/lib/quiz-answer-queue';

export function useQuizAnswerQueue<Payload>(
  send: (payload: Payload) => Promise<unknown>
) {
  const [state, setState] = useState<AnswerQueueState>({
    pending: 0,
    saving: false,
    error: null,
  });
  const [queue] = useState(
    () =>
      new QuizAnswerQueue<Payload>(async () => {
        throw new Error('답안 저장을 준비하고 있어요.');
      }, setState)
  );
  useEffect(() => queue.setSender(send), [queue, send]);
  useEffect(() => {
    queue.activate();
    return () => queue.cancel();
  }, [queue]);
  return { queue, ...state };
}
