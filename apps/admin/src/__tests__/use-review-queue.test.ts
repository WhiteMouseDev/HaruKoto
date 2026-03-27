import { describe, it, expect, vi } from 'vitest';

// Since the hook uses Next.js hooks (useRouter, useSearchParams), we test the logic
// by mocking next/navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useSearchParams: () => new URLSearchParams('queue=id1,id2,id3&qi=1'),
}));

import { renderHook } from '@testing-library/react';
import { useReviewQueue } from '@/hooks/use-review-queue';

describe('useReviewQueue', () => {
  it('returns isInQueue true when queue and qi params exist', () => {
    const { result } = renderHook(() => useReviewQueue('vocabulary'));
    expect(result.current.isInQueue).toBe(true);
    expect(result.current.position).toBe(2); // 1-based
    expect(result.current.total).toBe(3);
  });

  it('returns hasPrev true when not at first item', () => {
    const { result } = renderHook(() => useReviewQueue('vocabulary'));
    expect(result.current.hasPrev).toBe(true);
  });

  it('returns hasNext true when not at last item', () => {
    const { result } = renderHook(() => useReviewQueue('vocabulary'));
    expect(result.current.hasNext).toBe(true);
  });

  it('returns isLastItem false when not at last item', () => {
    const { result } = renderHook(() => useReviewQueue('vocabulary'));
    expect(result.current.isLastItem).toBe(false);
  });

  it('exposes goNext, goPrev, and exitQueue functions', () => {
    const { result } = renderHook(() => useReviewQueue('vocabulary'));
    expect(typeof result.current.goNext).toBe('function');
    expect(typeof result.current.goPrev).toBe('function');
    expect(typeof result.current.exitQueue).toBe('function');
  });
});
