import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import KanaQuizPage from '@/app/(app)/study/kana/[type]/quiz/page';
import { STUDY_WRITE_STOP_MESSAGE } from '@/lib/study-write-stop';
const mocks = vi.hoisted(() => ({
  start: vi.fn(),
  complete: vi.fn(),
  replace: vi.fn(),
}));
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: mocks.replace }),
  useSearchParams: () => new URLSearchParams(),
}));
vi.mock('@/hooks/use-kana-quiz', () => ({
  useStartKanaQuiz: () => ({ mutateAsync: mocks.start }),
  useCompleteKanaQuiz: () => ({
    mutateAsync: mocks.complete,
    isPending: false,
  }),
  useAnswerKanaQuestion: () => ({ mutate: vi.fn() }),
}));
vi.mock('@/components/features/kana/kana-quiz', () => ({
  KanaQuiz: ({ onComplete }: { onComplete: (value: object) => void }) => (
    <button
      onClick={() => onComplete({ correct: 1, total: 1, wrongQuestionIds: [] })}
    >
      마지막 답안 완료
    </button>
  ),
}));
beforeEach(() => {
  vi.resetAllMocks();
  mocks.start.mockResolvedValue({
    sessionId: 'same-kana',
    questions: [
      {
        questionId: 'q',
        questionText: 'あ',
        options: [{ id: 'a', text: '아' }],
        correctOptionId: 'a',
      },
    ],
  });
});
afterEach(cleanup);
it('keeps the same kana result on STOP completion and retries without redirecting or restarting', async () => {
  mocks.complete
    .mockRejectedValueOnce(new Error(STUDY_WRITE_STOP_MESSAGE))
    .mockResolvedValueOnce({
      accuracy: 100,
      xpEarned: 10,
      currentXp: 10,
      xpForNext: 100,
    });
  const params = Promise.resolve({ type: 'hiragana' });
  await act(async () => {
    render(<KanaQuizPage params={params} />);
  });
  fireEvent.click(
    await screen.findByRole('button', { name: '마지막 답안 완료' })
  );
  expect(await screen.findByRole('alert')).toHaveTextContent(
    STUDY_WRITE_STOP_MESSAGE
  );
  expect(mocks.replace).not.toHaveBeenCalled();
  fireEvent.click(
    screen.getByRole('button', { name: '같은 퀴즈 완료 다시 확인' })
  );
  await waitFor(() => expect(mocks.replace).toHaveBeenCalledOnce());
  expect(mocks.complete.mock.calls).toEqual([
    [{ sessionId: 'same-kana' }],
    [{ sessionId: 'same-kana' }],
  ]);
  expect(mocks.start).toHaveBeenCalledOnce();
});
