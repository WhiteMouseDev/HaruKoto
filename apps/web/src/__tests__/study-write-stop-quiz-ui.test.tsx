import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import QuizPage from '@/app/(app)/study/quiz/page';
import { STUDY_WRITE_STOP_MESSAGE } from '@/lib/study-write-stop';

const mocks = vi.hoisted(() => ({
  start: vi.fn(),
  resume: vi.fn(),
  answer: vi.fn(),
  retry: vi.fn(),
  complete: vi.fn(),
  replace: vi.fn(),
}));
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: mocks.replace }),
  useSearchParams: () => new URLSearchParams('resume=stored-session'),
}));
vi.mock('@/hooks/use-quiz', () => ({
  useStartQuiz: () => ({ mutateAsync: mocks.start }),
  useResumeQuiz: () => ({ mutateAsync: mocks.resume }),
  useAnswerQuestion: () => ({
    mutate: mocks.answer,
    mutateAsync: mocks.retry,
    isPending: false,
  }),
  useCompleteQuiz: () => ({ mutateAsync: mocks.complete, isPending: false }),
}));
vi.mock('@/hooks/use-wordbook', () => ({
  useAddWord: () => ({ mutate: vi.fn(), isPending: false }),
}));
vi.mock('@/lib/sounds', () => ({ playSound: vi.fn() }));
vi.mock('@/lib/show-events', () => ({ showGameEvents: vi.fn() }));
const question = (questionId: string, questionText: string) => ({
  questionId,
  questionText,
  options: [
    { id: 'a', text: '영화' },
    { id: 'b', text: '음악' },
  ],
  correctOptionId: 'a',
});
beforeEach(() => {
  vi.resetAllMocks();
  mocks.resume.mockResolvedValue({
    sessionId: 'stored-session',
    questions: [
      question('10000000-0000-4000-8000-000000000001', '映画'),
      question('10000000-0000-4000-8000-000000000002', '本'),
    ],
    totalQuestions: 2,
    quizType: 'VOCABULARY',
    answeredQuestionIds: [],
  });
  mocks.answer.mockImplementation((_payload, options) =>
    options.onError(new Error(STUDY_WRITE_STOP_MESSAGE))
  );
});
afterEach(cleanup);

it('keeps the selected question after STOP and retries exactly that answer before advancing', async () => {
  mocks.retry
    .mockRejectedValueOnce(new Error(STUDY_WRITE_STOP_MESSAGE))
    .mockResolvedValueOnce({});
  render(<QuizPage />);
  await screen.findByText('映画');
  fireEvent.click(screen.getByRole('button', { name: /1\s*영화/ }));
  expect(await screen.findByRole('alert')).toHaveTextContent(
    STUDY_WRITE_STOP_MESSAGE
  );
  const next = screen.getByRole('button', { name: '다음 문제 →' });
  expect(next).toBeDisabled();
  fireEvent.click(next);
  expect(screen.getByText('映画')).toBeInTheDocument();
  expect(mocks.complete).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole('button', { name: '같은 답안 다시 저장' }));
  await waitFor(() => expect(mocks.retry).toHaveBeenCalledTimes(1));
  expect(next).toBeDisabled();
  fireEvent.click(screen.getByRole('button', { name: '같은 답안 다시 저장' }));
  await waitFor(() => expect(next).toBeEnabled());
  expect(mocks.retry.mock.calls.map(([payload]) => payload)).toEqual([
    mocks.answer.mock.calls[0][0],
    mocks.answer.mock.calls[0][0],
  ]);
  fireEvent.click(next);
  expect(await screen.findByText('本')).toBeInTheDocument();
  expect(mocks.replace).not.toHaveBeenCalled();
});

it('retries a STOP-refused completion for the same session without resetting or starting another quiz', async () => {
  mocks.resume.mockResolvedValue({
    sessionId: 'stored-session',
    questions: [question('10000000-0000-4000-8000-000000000001', '映画')],
    totalQuestions: 1,
    quizType: 'VOCABULARY',
    answeredQuestionIds: [],
  });
  mocks.answer.mockImplementation(() => {});
  mocks.complete
    .mockRejectedValueOnce(new Error(STUDY_WRITE_STOP_MESSAGE))
    .mockResolvedValueOnce({
      correctCount: 1,
      totalQuestions: 1,
      xpEarned: 10,
      accuracy: 100,
      currentXp: 10,
      xpForNext: 100,
      events: [],
    });
  render(<QuizPage />);
  await screen.findByText('映画');
  fireEvent.click(screen.getByRole('button', { name: /1\s*영화/ }));
  fireEvent.click(screen.getByRole('button', { name: '결과 보기' }));
  await waitFor(() => expect(mocks.complete).toHaveBeenCalledTimes(1));
  expect(screen.getByText('映画')).toBeInTheDocument();
  expect(mocks.replace).not.toHaveBeenCalled();
  expect(mocks.start).not.toHaveBeenCalled();
  expect(mocks.resume).toHaveBeenCalledTimes(1);

  fireEvent.click(screen.getByRole('button', { name: '결과 보기' }));
  await waitFor(() => expect(mocks.replace).toHaveBeenCalledTimes(1));
  expect(mocks.complete.mock.calls.map(([payload]) => payload)).toEqual([
    { sessionId: 'stored-session' },
    { sessionId: 'stored-session' },
  ]);
  expect(mocks.answer).toHaveBeenCalledTimes(1);
  expect(mocks.start).not.toHaveBeenCalled();
  expect(mocks.resume).toHaveBeenCalledTimes(1);
  expect(mocks.replace).toHaveBeenCalledWith(
    expect.stringContaining('sessionId=stored-session')
  );
});
