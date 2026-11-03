import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useSavedQuizzes } from '@/hooks/use-saved-quizzes';

const mocks = vi.hoisted(() => ({
  fetch: vi.fn(),
  auth: null as
    | null
    | ((event: string, session: { user: { id: string } } | null) => void),
}));
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
const session = (id: string) => ({
  id,
  quizType: 'VOCABULARY',
  jlptLevel: 'N5',
  totalQuestions: 20,
  answeredCount: 1,
  remainingCount: 19,
  mode: 'normal',
  startedAt: '2026-11-01T00:00:00Z',
  resumeStatus: 'available',
  resumeReason: null,
});
const response = (
  sessions: ReturnType<typeof session>[],
  nextCursor: string | null = null
) => Response.json({ sessions, nextCursor });
function setup(filters: { quizType?: string; jlptLevel?: string } = {}) {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return renderHook(() => useSavedQuizzes(filters), {
    wrapper: ({ children }) => (
      <QueryClientProvider client={client}>{children}</QueryClientProvider>
    ),
  });
}
beforeEach(() => {
  vi.resetAllMocks();
  vi.stubGlobal('fetch', mocks.fetch);
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('saved quiz collection query', () => {
  it('keeps filter and cursor on the next bounded page', async () => {
    mocks.fetch
      .mockResolvedValueOnce(response([session('first')], 'cursor'))
      .mockResolvedValueOnce(response([session('second')]));
    const { result } = setup({ quizType: 'VOCABULARY', jlptLevel: 'N5' });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.hasNextPage).toBe(true);
    await act(async () => {
      await result.current.fetchNextPage();
    });
    expect(result.current.error).toBeNull();
    await waitFor(() => expect(result.current.data?.pages).toHaveLength(2));
    expect(
      result.current.data?.pages.flatMap((page) =>
        page.sessions.map((row) => row.id)
      )
    ).toEqual(['first', 'second']);
    const url = new URL(mocks.fetch.mock.calls[1][0], 'http://localhost');
    expect(Object.fromEntries(url.searchParams)).toEqual({
      limit: '20',
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
      cursor: 'cursor',
    });
  });
  it('uses the representative fallback only on 404 and retains its safe resume path', async () => {
    mocks.fetch
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(Response.json({ session: session('legacy') }));
    const { result } = setup();
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.pages[0]).toMatchObject({
      sessions: [
        { id: 'legacy', resumeStatus: 'available', remainingCount: null },
      ],
      nextCursor: null,
    });
    expect(mocks.fetch.mock.calls[1][0]).toBe('/api/v1/quiz/incomplete');
  });
  it('does not disguise server failure as an empty collection or fallback', async () => {
    mocks.fetch.mockResolvedValue(new Response(null, { status: 503 }));
    const { result } = setup();
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.data).toBeUndefined();
    expect(mocks.fetch).toHaveBeenCalledOnce();
  });
  it('ignores an old response after account switch and does not display the old collection', async () => {
    let resolveOld!: (value: Response) => void;
    mocks.fetch
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveOld = resolve;
          })
      )
      .mockResolvedValueOnce(response([session('B-only')]));
    const { result } = setup();
    await waitFor(() => expect(mocks.fetch).toHaveBeenCalledOnce());
    act(() => mocks.auth?.('SIGNED_IN', { user: { id: 'B' } }));
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    await act(async () => {
      resolveOld(response([session('A-private')]));
    });
    expect(result.current.data?.pages[0].sessions.map((row) => row.id)).toEqual(
      ['B-only']
    );
  });
});
