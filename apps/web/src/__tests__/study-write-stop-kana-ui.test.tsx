import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { KanaQuiz } from '@/components/features/kana/kana-quiz';
import { STUDY_WRITE_STOP_MESSAGE } from '@/lib/study-write-stop';
const mocks = vi.hoisted(() => ({ answer: vi.fn(), complete: vi.fn() }));
vi.mock('@/hooks/use-kana-quiz', () => ({
  useAnswerKanaQuestion: () => ({
    mutateAsync: mocks.answer,
    isPending: false,
  }),
}));
beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
});
const questions = ['あ', 'い'].map((questionText, i) => ({
  questionId: `q${i}`,
  questionText,
  questionSubText: null,
  options: [
    { id: 'a', text: '아' },
    { id: 'b', text: '이' },
  ],
  correctOptionId: 'a',
}));
it('does not let the kana feedback timer discard a STOP-refused choice', async () => {
  mocks.answer
    .mockRejectedValueOnce(new Error(STUDY_WRITE_STOP_MESSAGE))
    .mockRejectedValueOnce(new Error(STUDY_WRITE_STOP_MESSAGE))
    .mockResolvedValueOnce({});
  render(
    <KanaQuiz
      questions={questions}
      sessionId="saved-kana"
      onComplete={mocks.complete}
    />
  );
  await act(async () => {
    fireEvent.click(screen.getByRole('button', { name: '선택지: 아' }));
  });
  expect(screen.getByRole('alert')).toHaveTextContent(STUDY_WRITE_STOP_MESSAGE);
  await act(async () => {
    vi.advanceTimersByTime(1500);
  });
  expect(screen.getByText('1/2')).toBeInTheDocument();
  await act(async () => {
    fireEvent.click(
      screen.getByRole('button', { name: '같은 답안 다시 저장' })
    );
  });
  expect(screen.getByText('1/2')).toBeInTheDocument();
  await act(async () => {
    fireEvent.click(
      screen.getByRole('button', { name: '같은 답안 다시 저장' })
    );
  });
  await act(async () => {
    vi.advanceTimersByTime(1500);
  });
  expect(screen.getByText('2/2')).toBeInTheDocument();
  expect(mocks.answer.mock.calls.map(([payload]) => payload)).toEqual(
    Array(3).fill({
      sessionId: 'saved-kana',
      questionId: 'q0',
      selectedOptionId: 'a',
    })
  );
  expect(mocks.complete).not.toHaveBeenCalled();
});

it('does not advance when a pending kana answer is acknowledged after unmount', async () => {
  let acknowledge: (value: unknown) => void = () => {};
  mocks.answer.mockImplementation(
    () =>
      new Promise((resolve) => {
        acknowledge = resolve;
      })
  );
  const { unmount } = render(
    <KanaQuiz
      questions={[questions[0]]}
      sessionId="saved-kana"
      onComplete={mocks.complete}
    />
  );
  await act(async () => {
    fireEvent.click(screen.getByRole('button', { name: '선택지: 아' }));
  });
  expect(mocks.answer).toHaveBeenCalledTimes(1);
  unmount();
  const timersAfterUnmount = vi.getTimerCount();
  await act(async () => {
    acknowledge({});
  });
  expect(vi.getTimerCount()).toBe(timersAfterUnmount);
  await act(async () => {
    vi.advanceTimersByTime(2000);
  });
  expect(mocks.complete).not.toHaveBeenCalled();
});

it('cancels an acknowledged kana answer feedback timer on unmount', async () => {
  mocks.answer.mockResolvedValue({});
  const { unmount } = render(
    <KanaQuiz
      questions={[questions[0]]}
      sessionId="saved-kana"
      onComplete={mocks.complete}
    />
  );
  await act(async () => {
    fireEvent.click(screen.getByRole('button', { name: '선택지: 아' }));
  });
  expect(mocks.answer).toHaveBeenCalledTimes(1);
  unmount();
  await act(async () => {
    vi.advanceTimersByTime(2000);
  });
  expect(mocks.complete).not.toHaveBeenCalled();
});
