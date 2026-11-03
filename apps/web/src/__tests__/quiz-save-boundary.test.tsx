import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import QuizPage from '@/app/(app)/study/quiz/page';
const mocks = vi.hoisted(() => ({
  answer: vi.fn(),
  resume: vi.fn(),
  complete: vi.fn(),
  replace: vi.fn(),
  auth: null as
    | null
    | ((event: string, session: { user: { id: string } } | null) => void),
}));
vi.mock('next/navigation', () => ({
  useRouter: () => ({ replace: mocks.replace, push: vi.fn() }),
  useSearchParams: () => new URLSearchParams('resume=saved-session'),
}));
vi.mock('@/hooks/use-quiz', () => ({
  useStartQuiz: () => ({ mutateAsync: vi.fn() }),
  useResumeQuiz: () => ({ mutateAsync: mocks.resume }),
  useAnswerQuestion: () => ({ mutateAsync: mocks.answer }),
  useCompleteQuiz: () => ({ mutateAsync: mocks.complete }),
}));
vi.mock('@/hooks/use-wordbook', () => ({ useAddWord: () => ({}) }));
vi.mock('@/lib/sounds', () => ({ playSound: vi.fn() }));
vi.mock('@/lib/show-events', () => ({ showGameEvents: vi.fn() }));
vi.mock('@/lib/supabase/client', () => ({
  createClient: () => ({
    auth: {
      getSession: async () => ({ data: { session: { user: { id: 'A' } } } }),
      onAuthStateChange: (callback: typeof mocks.auth) => {
        mocks.auth = callback;
        return { data: { subscription: { unsubscribe: vi.fn() } } };
      },
    },
  }),
}));
vi.mock('@/components/features/quiz/sentence-arrange', () => ({
  SentenceArrangeQuiz: ({
    onAnswer,
    onComplete,
  }: {
    onAnswer: (id: string, correct: boolean) => void;
    onComplete: () => void;
  }) => (
    <button
      onClick={() => {
        onAnswer('10000000-0000-4000-8000-000000000001', true);
        onComplete();
      }}
    >
      마지막 문항 제출과 완료
    </button>
  ),
}));
beforeEach(() => {
  vi.resetAllMocks();
  mocks.resume.mockResolvedValue({
    sessionId: 'saved-session',
    quizType: 'SENTENCE_ARRANGE',
    mode: 'arrange',
    totalQuestions: 1,
    answeredQuestionIds: [],
    questions: [
      {
        questionId: '10000000-0000-4000-8000-000000000001',
        questionText: '영화',
        options: [],
        correctOptionId: '10000000-0000-4000-8000-000000000001',
        koreanSentence: '영화',
        japaneseSentence: '映画',
        tokens: [{ text: '映画', type: 'noun', meaning: '영화', order: 0 }],
      },
    ],
  });
  mocks.complete.mockResolvedValue({
    correctCount: 1,
    totalQuestions: 1,
    xpEarned: 10,
    accuracy: 100,
  });
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.restoreAllMocks();
});
describe('web special-mode save boundary', () => {
  it('waits for the final answer ACK before sending completion', async () => {
    let accept!: (result: { answerId: string }) => void;
    mocks.answer.mockImplementation(
      () =>
        new Promise((resolve) => {
          accept = resolve;
        })
    );
    render(<QuizPage />);
    fireEvent.click(await screen.findByText('마지막 문항 제출과 완료'));
    await waitFor(() => expect(mocks.answer).toHaveBeenCalledOnce());
    expect(
      screen.getByText('마지막 문항 제출과 완료').closest('[inert]')
    ).not.toBeNull();
    expect(mocks.complete).not.toHaveBeenCalled();
    accept({ answerId: mocks.answer.mock.calls[0][0].attemptId });
    await waitFor(() =>
      expect(mocks.complete).toHaveBeenCalledWith({
        sessionId: 'saved-session',
      })
    );
    expect(mocks.replace).toHaveBeenCalledOnce();
  });
  it('keeps the original attempt ID on retry after a lost response before completing', async () => {
    mocks.answer
      .mockRejectedValueOnce(new Error('response lost'))
      .mockImplementationOnce(async (payload) => ({
        answerId: payload.attemptId,
      }));
    render(<QuizPage />);
    fireEvent.click(await screen.findByText('마지막 문항 제출과 완료'));
    fireEvent.click(await screen.findByText('같은 답안 다시 저장'));
    await waitFor(() => expect(mocks.complete).toHaveBeenCalledOnce());
    expect(mocks.answer.mock.calls[0][0]).toEqual(
      mocks.answer.mock.calls[1][0]
    );
    expect(mocks.answer.mock.calls[0][0]).toMatchObject({
      previousAttemptId: null,
    });
  });
  it('does not complete or navigate after the account changes while an answer is pending', async () => {
    let accept!: (result: { answerId: string }) => void;
    mocks.answer.mockImplementation(
      () =>
        new Promise((resolve) => {
          accept = resolve;
        })
    );
    render(<QuizPage />);
    fireEvent.click(await screen.findByText('마지막 문항 제출과 완료'));
    await waitFor(() => expect(mocks.answer).toHaveBeenCalledOnce());
    act(() => mocks.auth?.('SIGNED_IN', { user: { id: 'B' } }));
    accept({ answerId: mocks.answer.mock.calls[0][0].attemptId });
    expect(
      await screen.findByText(
        '계정이 변경됐어요. 현재 계정의 저장된 퀴즈에서 다시 시작해 주세요.'
      )
    ).toBeInTheDocument();
    expect(mocks.complete).not.toHaveBeenCalled();
    expect(mocks.replace).not.toHaveBeenCalled();
  });
  it('leaves loading safely when the account changes before resume returns', async () => {
    let resume!: (value: unknown) => void;
    mocks.resume.mockImplementation(
      () =>
        new Promise((resolve) => {
          resume = resolve;
        })
    );
    render(<QuizPage />);
    await waitFor(() => expect(mocks.resume).toHaveBeenCalledOnce());
    act(() => mocks.auth?.('SIGNED_IN', { user: { id: 'B' } }));
    expect(
      await screen.findByText(
        '계정이 변경됐어요. 현재 계정의 저장된 퀴즈에서 다시 시작해 주세요.'
      )
    ).toBeInTheDocument();
    await act(async () => {
      resume({ sessionId: 'old-account-session', questions: [] });
    });
    expect(
      screen.queryByText('마지막 문항 제출과 완료')
    ).not.toBeInTheDocument();
    expect(mocks.complete).not.toHaveBeenCalled();
  });
});

it('counts only visible foreground time in a new answer', async () => {
  vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'Date'] });
  const visibility = vi
    .spyOn(document, 'visibilityState', 'get')
    .mockReturnValue('visible');
  mocks.resume.mockResolvedValue({
    sessionId: 'saved-session',
    quizType: 'VOCABULARY',
    mode: 'normal',
    totalQuestions: 1,
    answeredQuestionIds: [],
    questions: [
      {
        questionId: '10000000-0000-4000-8000-000000000001',
        questionText: '映画',
        options: [{ id: 'right', text: '영화' }],
        correctOptionId: 'right',
      },
    ],
  });
  mocks.answer.mockImplementation(async (payload) => ({
    answerId: payload.attemptId,
  }));
  render(<QuizPage />);
  await screen.findByText('映画');
  await act(async () => {
    await vi.advanceTimersByTimeAsync(2000);
  });
  visibility.mockReturnValue('hidden');
  await act(async () => {
    await vi.advanceTimersByTimeAsync(60000);
  });
  visibility.mockReturnValue('visible');
  await act(async () => {
    await vi.advanceTimersByTimeAsync(1000);
  });
  fireEvent.click(screen.getByRole('button', { name: /1\s*영화/ }));
  await waitFor(() => expect(mocks.answer).toHaveBeenCalledOnce());
  expect(mocks.answer.mock.calls[0][0].timeSpentSeconds).toBe(3);
});
