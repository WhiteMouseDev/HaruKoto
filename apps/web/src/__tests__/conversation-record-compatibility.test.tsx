import { Suspense } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import FeedbackPage from '@/app/(app)/chat/[conversationId]/feedback/page';
import { GET } from '@/app/api/v1/chat/[conversationId]/route';

const mocks = vi.hoisted(() => ({
  findUnique: vi.fn(),
  getUser: vi.fn(),
  fetch: vi.fn(),
  push: vi.fn(),
  invalidateQueries: vi.fn(),
}));

vi.mock('@harukoto/database', () => ({
  prisma: { conversation: { findUnique: mocks.findUnique } },
}));
vi.mock('@/lib/supabase/server', () => ({
  createClient: () => ({ auth: { getUser: mocks.getUser } }),
}));
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: mocks.push }),
}));
vi.mock('@tanstack/react-query', () => ({
  useQueryClient: () => ({ invalidateQueries: mocks.invalidateQueries }),
}));
vi.mock('@/hooks/use-wordbook', () => ({
  useAddWord: () => ({ mutateAsync: vi.fn(), isPending: false }),
}));

const conversationId = '10000000-0000-4000-8000-000000000001';
const userId = '20000000-0000-4000-8000-000000000001';
const mobileRecord = {
  id: conversationId,
  userId,
  type: 'VOICE',
  messages: [
    { role: 'system', content: 'Private scenario instruction' },
    { role: 'assistant', content: 'ご予約のお名前をお願いします。' },
    { role: 'tool', content: 'Private tool result' },
    { role: 'user', content: 'キムです。' },
  ],
  messageCount: 2,
  feedbackSummary: null,
  endedAt: new Date('2026-11-03T06:00:00Z'),
  scenario: {
    id: '30000000-0000-4000-8000-000000000001',
    title: '호텔 체크인',
    titleJa: 'ホテルのチェックイン',
    difficulty: 'BEGINNER',
    situation: '호텔 도착',
    yourRole: '손님',
    aiRole: '직원',
  },
};

beforeEach(() => {
  vi.resetAllMocks();
  sessionStorage.clear();
  vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
  mocks.getUser.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.findUnique.mockResolvedValue(mobileRecord);
  mocks.fetch.mockImplementation(() =>
    GET(new Request(`http://localhost/api/v1/chat/${conversationId}`), {
      params: Promise.resolve({ conversationId }),
    })
  );
  vi.stubGlobal('fetch', mocks.fetch);
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

async function openRecord() {
  const params = Promise.resolve({ conversationId });
  await act(async () => {
    render(
      <Suspense fallback="Loading">
        <FeedbackPage params={params} />
      </Suspense>
    );
  });
}

describe('mobile conversation records on web', () => {
  it('shows saved original turns without scores when analysis was disabled or failed', async () => {
    await openRecord();

    expect(await screen.findByText('キムです。')).toBeInTheDocument();
    expect(
      screen.getByText('ご予約のお名前をお願いします。')
    ).toBeInTheDocument();
    expect(
      screen.getByRole('heading', { name: '회화 기록' })
    ).toBeInTheDocument();
    expect(
      screen.getByText('분석 결과 없이 저장된 회화 기록이에요.')
    ).toBeInTheDocument();
    expect(
      screen.queryByText('Private scenario instruction')
    ).not.toBeInTheDocument();
    expect(screen.queryByText('Private tool result')).not.toBeInTheDocument();
    expect(screen.queryByText(/\/ 5/)).not.toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: '번역 보기' })
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText('피드백 데이터를 불러올 수 없습니다.')
    ).not.toBeInTheDocument();
    expect(mocks.fetch).toHaveBeenCalledExactlyOnceWith(
      `/api/v1/chat/${conversationId}`
    );
  });

  it('distinguishes an empty saved call from a failed record request', async () => {
    mocks.findUnique.mockResolvedValue({
      ...mobileRecord,
      messages: [],
      messageCount: 0,
    });
    await openRecord();

    expect(
      await screen.findByText('저장된 대화 내용이 없어요.')
    ).toBeInTheDocument();
    expect(
      screen.queryByText('피드백 데이터를 불러올 수 없습니다.')
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/\/ 5/)).not.toBeInTheDocument();
  });

  it('keeps legacy text feedback and its JSON assistant message readable without inventing missing scores', async () => {
    mocks.findUnique.mockResolvedValue({
      ...mobileRecord,
      type: 'TEXT',
      messages: [
        {
          role: 'assistant',
          content: JSON.stringify({
            messageJa: 'ようこそ。',
            messageKo: '환영합니다.',
          }),
        },
      ],
      feedbackSummary: {
        overallScore: null,
        strengths: ['정중하게 인사했어요'],
        recommendedExpressions: ['お願いします。'],
      },
    });
    await openRecord();

    expect(await screen.findByText('ようこそ。')).toBeInTheDocument();
    expect(screen.getByText('정중하게 인사했어요')).toBeInTheDocument();
    expect(screen.getAllByText('お願いします。').length).toBeGreaterThan(0);
    expect(screen.queryByText(/\/ 5/)).not.toBeInTheDocument();
  });

  it('preserves scored live feedback and translated turns', async () => {
    mocks.findUnique.mockResolvedValue({
      ...mobileRecord,
      feedbackSummary: {
        overallScore: 80,
        fluency: 80,
        accuracy: 80,
        vocabularyDiversity: 80,
        naturalness: 80,
        strengths: [],
        improvements: [],
        recommendedExpressions: [{ ja: '予約しました。', ko: '예약했어요.' }],
        corrections: [],
        translatedTranscript: [
          { role: 'user', ja: 'キムです。', ko: '김입니다.' },
        ],
      },
    });
    await openRecord();

    expect(await screen.findByText('4.0 / 5')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: '번역 보기' }));
    expect(await screen.findByText('김입니다.')).toBeInTheDocument();
    expect(screen.getByText('예약했어요.')).toBeInTheDocument();
  });

  it('handles legacy translated turns with absent translations and excludes internal roles', async () => {
    mocks.findUnique.mockResolvedValue({
      ...mobileRecord,
      feedbackSummary: {
        strengths: [],
        improvements: [],
        recommendedExpressions: [],
        translatedTranscript: [
          { role: 'system', ja: 'Private translated instruction' },
          { role: 'tool', ja: 'Private translated tool result', ko: null },
          { role: 'ai', ja: 'いらっしゃいませ。', ko: null },
          { role: 'user', ja: '予約しました。' },
        ],
      },
    });
    await openRecord();

    expect(await screen.findByText('いらっしゃいませ。')).toBeInTheDocument();
    expect(screen.getByText('予約しました。')).toBeInTheDocument();
    expect(
      screen.queryByText('Private translated instruction')
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText('Private translated tool result')
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: '번역 보기' })
    ).not.toBeInTheDocument();
  });

  it('keeps a legacy record readable when its stored messages are not an array', async () => {
    mocks.findUnique.mockResolvedValue({ ...mobileRecord, messages: null });
    await openRecord();

    expect(
      await screen.findByText('저장된 대화 내용이 없어요.')
    ).toBeInTheDocument();
    expect(
      screen.queryByText('피드백 데이터를 불러올 수 없습니다.')
    ).not.toBeInTheDocument();
  });

  it.each(['not-found', 'network-error'])(
    'shows load failure for %s instead of an unanalyzed record',
    async (failure) => {
      if (failure === 'not-found') mocks.findUnique.mockResolvedValue(null);
      else mocks.fetch.mockRejectedValue(new Error('Network unavailable'));
      await openRecord();

      expect(
        await screen.findByText('피드백 데이터를 불러올 수 없습니다.')
      ).toBeInTheDocument();
      expect(
        screen.queryByText('분석 결과 없이 저장된 회화 기록이에요.')
      ).not.toBeInTheDocument();
    }
  );
});
