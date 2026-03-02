import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { showGameEvents } from '@/lib/show-events';

// Mock sonner
vi.mock('sonner', () => ({
  toast: {
    success: vi.fn(),
  },
}));

describe('showGameEvents', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should do nothing for undefined events', async () => {
    const { toast } = await import('sonner');
    showGameEvents(undefined);
    vi.advanceTimersByTime(5000);
    expect(toast.success).not.toHaveBeenCalled();
  });

  it('should do nothing for empty events array', async () => {
    const { toast } = await import('sonner');
    showGameEvents([]);
    vi.advanceTimersByTime(5000);
    expect(toast.success).not.toHaveBeenCalled();
  });

  it('should show level_up toast', async () => {
    const { toast } = await import('sonner');
    showGameEvents([
      { type: 'level_up', data: { newLevel: 5 } },
    ]);
    vi.advanceTimersByTime(0);
    expect(toast.success).toHaveBeenCalledWith(
      '레벨 업! 레벨 5 도달!',
      expect.objectContaining({ icon: expect.anything() })
    );
  });

  it('should show streak toast', async () => {
    const { toast } = await import('sonner');
    showGameEvents([
      { type: 'streak', data: { streakCount: 7 } },
    ]);
    vi.advanceTimersByTime(0);
    expect(toast.success).toHaveBeenCalledWith(
      '7일째 연속 학습 중!',
      expect.objectContaining({ icon: expect.anything() })
    );
  });

  it('should show achievement toast', async () => {
    const { toast } = await import('sonner');
    showGameEvents([
      { type: 'achievement', data: { label: '첫 퀴즈 완료!', emoji: 'target' } },
    ]);
    vi.advanceTimersByTime(0);
    expect(toast.success).toHaveBeenCalledWith(
      '업적 달성! 첫 퀴즈 완료!',
      expect.objectContaining({ icon: expect.anything() })
    );
  });

  it('should stagger multiple events with 800ms delay', async () => {
    const { toast } = await import('sonner');
    showGameEvents([
      { type: 'level_up', data: { newLevel: 2 } },
      { type: 'streak', data: { streakCount: 3 } },
      { type: 'achievement', data: { label: 'Test', emoji: 'trophy' } },
    ]);

    // At t=0, first event fires
    vi.advanceTimersByTime(0);
    expect(toast.success).toHaveBeenCalledTimes(1);

    // At t=800, second event fires
    vi.advanceTimersByTime(800);
    expect(toast.success).toHaveBeenCalledTimes(2);

    // At t=1600, third event fires
    vi.advanceTimersByTime(800);
    expect(toast.success).toHaveBeenCalledTimes(3);
  });
});
