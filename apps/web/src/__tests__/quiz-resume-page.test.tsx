import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import QuizPage from '@/app/(app)/study/quiz/page';
import { QUIZ_WEB_UNSUPPORTED_MESSAGE } from '@/lib/quiz-session-snapshot';

const mocks = vi.hoisted(() => ({
  resume: vi.fn(),
  start: vi.fn(),
  answer: vi.fn(),
  complete: vi.fn(),
  push: vi.fn(),
  replace: vi.fn(),
}));
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: mocks.push, replace: mocks.replace }),
  useSearchParams: () => new URLSearchParams('resume=saved-session'),
}));
vi.mock('@/hooks/use-quiz', () => ({
  useResumeQuiz: () => ({ mutateAsync: mocks.resume }),
  useStartQuiz: () => ({ mutateAsync: mocks.start }),
  useAnswerQuestion: () => ({ mutate: mocks.answer }),
  useCompleteQuiz: () => ({ mutateAsync: mocks.complete, isPending: false }),
}));
vi.mock('@/hooks/use-wordbook', () => ({
  useAddWord: () => ({ isPending: false, mutate: vi.fn() }),
}));
vi.mock('@/lib/show-events', () => ({ showGameEvents: vi.fn() }));
vi.mock('@/lib/sounds', () => ({ playSound: vi.fn() }));

const firstId = '10000000-0000-4000-8000-000000000001';
const secondId = '10000000-0000-4000-8000-000000000002';
const question = (id = firstId, word = '映画') => ({
  questionId: id,
  questionText: word,
  questionSubText: null,
  hint: null,
  options: [
    { id: 'correct', text: '영화' },
    { id: 'other', text: '음악' },
  ],
  correctOptionId: 'correct',
});
const response = () => ({
  sessionId: 'saved-session',
  questions: [question()],
  answeredQuestionIds: [],
  correctCount: 0,
  quizType: 'VOCABULARY',
  totalQuestions: 1,
  mode: 'normal',
});

beforeEach(() => {
  vi.resetAllMocks();
  mocks.resume.mockResolvedValue(response());
  mocks.complete.mockResolvedValue({
    correctCount: 1,
    totalQuestions: 1,
    xpEarned: 10,
    accuracy: 100,
    events: [],
  });
});
afterEach(cleanup);

describe('web resume UI', () => {
  it('shows the app guidance without an automatic start, answer, completion or permanent-error retry', async () => {
    mocks.resume.mockRejectedValue(new Error(QUIZ_WEB_UNSUPPORTED_MESSAGE));
    render(<QuizPage />);
    expect(await screen.findByRole('alert')).toHaveTextContent(
      QUIZ_WEB_UNSUPPORTED_MESSAGE
    );
    expect(
      screen.queryByRole('button', { name: '다시 시도' })
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: '학습으로 돌아가기' }));
    expect(mocks.push).toHaveBeenCalledWith('/study');
    expect(mocks.resume).toHaveBeenCalledTimes(1);
    expect(mocks.start).not.toHaveBeenCalled();
    expect(mocks.answer).not.toHaveBeenCalled();
    expect(mocks.complete).not.toHaveBeenCalled();
  });

  it('retries only the same saved session after a transient load error', async () => {
    mocks.resume
      .mockRejectedValueOnce(new Error('Network unavailable'))
      .mockResolvedValueOnce(response());
    render(<QuizPage />);
    fireEvent.click(await screen.findByRole('button', { name: '다시 시도' }));
    expect(await screen.findByText('映画')).toBeInTheDocument();
    expect(mocks.resume.mock.calls).toEqual([
      [{ sessionId: 'saved-session' }],
      [{ sessionId: 'saved-session' }],
    ]);
    expect(mocks.start).not.toHaveBeenCalled();
    expect(mocks.answer).not.toHaveBeenCalled();
    expect(mocks.complete).not.toHaveBeenCalled();
  });

  it('uses answered IDs rather than slicing that many entries from the original list', async () => {
    mocks.resume.mockResolvedValue({
      ...response(),
      questions: [question(firstId, '未回答'), question(secondId, '保存済み')],
      answeredQuestionIds: [secondId],
      totalQuestions: 2,
    });
    render(<QuizPage />);
    expect(await screen.findByText('未回答')).toBeInTheDocument();
    expect(screen.queryByText('保存済み')).not.toBeInTheDocument();
    expect(screen.getByText('2/2')).toBeInTheDocument();
    expect(mocks.answer).not.toHaveBeenCalled();
  });

  it('keeps an all-saved native arrange session on an explicit result action', async () => {
    mocks.resume.mockResolvedValue({
      ...response(),
      quizType: 'SENTENCE_ARRANGE',
      mode: 'arrange',
      answeredQuestionIds: [firstId],
      correctCount: 1,
      questions: [
        {
          ...question(),
          options: [],
          correctOptionId: firstId,
          koreanSentence: '영화를 봅니다',
          japaneseSentence: '映画を見ます',
          tokens: [{ text: '映画', type: 'noun', meaning: '영화', order: 0 }],
        },
      ],
    });
    render(<QuizPage />);
    expect(
      await screen.findByText('모든 답안이 저장됐어요')
    ).toBeInTheDocument();
    expect(mocks.complete).not.toHaveBeenCalled();
    expect(mocks.start).not.toHaveBeenCalled();
    expect(mocks.answer).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: '결과 확인하기' }));
    await waitFor(() =>
      expect(mocks.complete).toHaveBeenCalledWith({
        sessionId: 'saved-session',
      })
    );
    await waitFor(() => expect(mocks.replace).toHaveBeenCalledTimes(1));
  });

  it('does not infer a playable empty-options question from an old server response', async () => {
    mocks.resume.mockResolvedValue({
      ...response(),
      mode: undefined,
      questions: [{ ...question(), options: [] }],
    });
    render(<QuizPage />);
    expect(await screen.findByRole('alert')).toHaveTextContent(
      '저장된 학습 기록은 유지됩니다.'
    );
    expect(
      screen.queryByRole('button', { name: '다시 시도' })
    ).not.toBeInTheDocument();
    expect(mocks.answer).not.toHaveBeenCalled();
    expect(mocks.complete).not.toHaveBeenCalled();
    expect(mocks.start).not.toHaveBeenCalled();
  });
});
