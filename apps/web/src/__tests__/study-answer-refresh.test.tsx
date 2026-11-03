import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, renderHook } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAnswerQuestion } from '@/hooks/use-quiz';
import { useAnswerKanaQuestion } from '@/hooks/use-kana-quiz';
import { STUDY_WRITE_STOP_MESSAGE } from '@/lib/study-write-stop';

const mocks = vi.hoisted(() => ({
  owner: 'account-a' as string | null,
  listener: null as
    | null
    | ((event: string, session: { user: { id: string } } | null) => void),
  fetch: vi.fn(),
  toast: vi.fn(),
  unsubscribe: vi.fn(),
}));
vi.mock('@/lib/api', () => ({ apiFetch: mocks.fetch }));
vi.mock('sonner', () => ({ toast: { error: mocks.toast } }));
vi.mock('@/lib/supabase/client', () => ({
  createClient: () => ({
    auth: {
      getSession: async () => ({
        data: { session: mocks.owner ? { user: { id: mocks.owner } } : null },
      }),
      onAuthStateChange: (listener: typeof mocks.listener) => {
        mocks.listener = listener;
        return { data: { subscription: { unsubscribe: mocks.unsubscribe } } };
      },
    },
  }),
}));

beforeEach(() => {
  vi.resetAllMocks();
  mocks.owner = 'account-a';
  mocks.listener = null;
});
afterEach(cleanup);
const parameters = {
  sessionId: 'session',
  questionId: 'question',
  selectedOptionId: 'wrong',
  isCorrect: false,
  timeSpentSeconds: 0,
  questionType: 'VOCABULARY',
};

describe.each([
  ['normal', useAnswerQuestion],
  ['kana', useAnswerKanaQuestion],
] as const)('%s answer refresh', (_name, useAnswer) => {
  function setup() {
    const client = new QueryClient({
      defaultOptions: { mutations: { retry: false } },
    });
    const invalidate = vi
      .spyOn(client, 'invalidateQueries')
      .mockResolvedValue();
    const hook = renderHook(() => useAnswer(), {
      wrapper: ({ children }) => (
        <QueryClientProvider client={client}>{children}</QueryClientProvider>
      ),
    });
    return { ...hook, invalidate };
  }

  it('refreshes attendance and saved progress only after server ACK and leaves target/SRS caches alone', async () => {
    let release!: (value: unknown) => void;
    mocks.fetch.mockReturnValue(
      new Promise((resolve) => {
        release = resolve;
      })
    );
    const { result, invalidate } = setup();
    let pending!: Promise<unknown>;
    await act(async () => {
      pending = result.current.mutateAsync(parameters);
    });
    expect(invalidate).not.toHaveBeenCalled();
    await act(async () => {
      release({ success: true });
      await pending;
    });
    expect(invalidate.mock.calls.map((call) => call[0]?.queryKey)).toEqual([
      ['dashboard'],
      ['profile'],
      ['stats-history'],
      ...(_name === 'normal' ? [['quiz-incomplete']] : []),
    ]);
  });

  it('does not refresh attendance on answer failure', async () => {
    mocks.fetch.mockRejectedValue(new Error('save failed'));
    const { result, invalidate } = setup();
    await act(async () => {
      await expect(result.current.mutateAsync(parameters)).rejects.toThrow(
        'save failed'
      );
    });
    expect(invalidate).not.toHaveBeenCalled();
    expect(mocks.toast).toHaveBeenCalledWith('답안 저장에 실패했어요.');
  });

  it('preserves the STOP explanation without treating a refused answer as saved', async () => {
    mocks.fetch.mockRejectedValue(new Error(STUDY_WRITE_STOP_MESSAGE));
    const { result, invalidate } = setup();
    await act(async () => {
      await expect(result.current.mutateAsync(parameters)).rejects.toThrow(
        STUDY_WRITE_STOP_MESSAGE
      );
    });
    expect(invalidate).not.toHaveBeenCalled();
    expect(mocks.toast).toHaveBeenCalledWith(STUDY_WRITE_STOP_MESSAGE);
  });

  it('ignores an old ACK after an A→B→A login generation change', async () => {
    let release!: (value: unknown) => void;
    mocks.fetch.mockReturnValue(
      new Promise((resolve) => {
        release = resolve;
      })
    );
    const { result, invalidate } = setup();
    let pending!: Promise<unknown>;
    await act(async () => {
      pending = result.current.mutateAsync(parameters);
    });
    act(() => {
      mocks.owner = 'account-b';
      mocks.listener?.('SIGNED_IN', { user: { id: 'account-b' } });
      mocks.owner = 'account-a';
      mocks.listener?.('SIGNED_IN', { user: { id: 'account-a' } });
    });
    await act(async () => {
      release({ success: true });
      await pending;
    });
    expect(invalidate).not.toHaveBeenCalled();
  });
});
