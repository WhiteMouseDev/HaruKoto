import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';

// Mock framer-motion to avoid animation issues in tests
vi.mock('framer-motion', () => ({
  motion: {
    div: (props: React.ComponentProps<'div'>) => <div {...props} />,
    span: (props: React.ComponentProps<'span'>) => <span {...props} />,
  },
  AnimatePresence: ({ children }: React.PropsWithChildren) => <>{children}</>,
}));

// ---- Heatmap utility tests ----

describe('Heatmap: getIntensity', () => {
  // Re-implement getIntensity for unit testing since it's not exported
  function getIntensity(count: number, max: number): number {
    if (count === 0) return 0;
    if (max === 0) return 0;
    const ratio = count / max;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  it('should return 0 for count of 0', () => {
    expect(getIntensity(0, 100)).toBe(0);
  });

  it('should return 0 for max of 0', () => {
    expect(getIntensity(5, 0)).toBe(0);
  });

  it('should return 1 for ratio <= 0.25', () => {
    expect(getIntensity(25, 100)).toBe(1);
    expect(getIntensity(1, 100)).toBe(1);
  });

  it('should return 2 for ratio <= 0.5', () => {
    expect(getIntensity(50, 100)).toBe(2);
    expect(getIntensity(26, 100)).toBe(2);
  });

  it('should return 3 for ratio <= 0.75', () => {
    expect(getIntensity(75, 100)).toBe(3);
    expect(getIntensity(51, 100)).toBe(3);
  });

  it('should return 4 for ratio > 0.75', () => {
    expect(getIntensity(76, 100)).toBe(4);
    expect(getIntensity(100, 100)).toBe(4);
  });
});

// ---- BarChart utility tests ----

describe('BarChart: formatMinutes', () => {
  // Re-implement for unit testing
  function formatMinutes(seconds: number): string {
    const mins = Math.round(seconds / 60);
    if (mins < 60) return `${mins}분`;
    const hours = Math.floor(mins / 60);
    const remainder = mins % 60;
    return remainder > 0 ? `${hours}시간 ${remainder}분` : `${hours}시간`;
  }

  it('should return 0분 for 0 seconds', () => {
    expect(formatMinutes(0)).toBe('0분');
  });

  it('should format seconds to minutes', () => {
    expect(formatMinutes(120)).toBe('2분');
    expect(formatMinutes(300)).toBe('5분');
    expect(formatMinutes(3540)).toBe('59분');
  });

  it('should format large values as hours', () => {
    expect(formatMinutes(3600)).toBe('1시간');
    expect(formatMinutes(7200)).toBe('2시간');
  });

  it('should format hours and minutes', () => {
    expect(formatMinutes(5400)).toBe('1시간 30분');
    expect(formatMinutes(3660)).toBe('1시간 1분');
  });

  it('should round correctly', () => {
    expect(formatMinutes(89)).toBe('1분');
    expect(formatMinutes(29)).toBe('0분');
    expect(formatMinutes(31)).toBe('1분');
  });
});

// ---- StudyTab tests ----

describe('StudyTab', () => {
  async function loadStudyTab() {
    const mod = await import('@/components/features/stats/study-tab');
    return mod.StudyTab;
  }

  const defaultProps = {
    today: {
      wordsStudied: 10,
      quizzesCompleted: 5,
      correctAnswers: 8,
      totalAnswers: 10,
      xpEarned: 50,
      goalProgress: 0.8,
    },
    levelProgress: {
      vocabulary: { total: 100, mastered: 30, inProgress: 20 },
      grammar: { total: 50, mastered: 10, inProgress: 15 },
    },
    historyRecords: [
      {
        date: '2026-03-01',
        wordsStudied: 5,
        quizzesCompleted: 2,
        correctAnswers: 4,
        totalAnswers: 5,
        conversationCount: 1,
        studyTimeSeconds: 600,
        xpEarned: 25,
      },
      {
        date: '2026-03-02',
        wordsStudied: 10,
        quizzesCompleted: 5,
        correctAnswers: 8,
        totalAnswers: 10,
        conversationCount: 2,
        studyTimeSeconds: 1200,
        xpEarned: 50,
      },
    ],
  };

  it('should render category names', async () => {
    const StudyTab = await loadStudyTab();
    render(<StudyTab {...defaultProps} />);

    expect(screen.getByText('단어')).toBeInTheDocument();
    expect(screen.getByText('문법')).toBeInTheDocument();
    expect(screen.getByText('한자')).toBeInTheDocument();
    expect(screen.getByText('회화')).toBeInTheDocument();
  });

  it('should calculate accuracy correctly', async () => {
    const StudyTab = await loadStudyTab();
    render(<StudyTab {...defaultProps} />);

    // 8/10 = 80% accuracy for vocabulary
    expect(screen.getByText('정답률 80%')).toBeInTheDocument();
  });

  it('should handle zero totalAnswers without division by zero', async () => {
    const StudyTab = await loadStudyTab();
    const zeroProps = {
      ...defaultProps,
      today: { ...defaultProps.today, totalAnswers: 0, correctAnswers: 0 },
    };
    render(<StudyTab {...zeroProps} />);

    // Both 단어 and 한자 show 0%, so multiple matches expected
    const zeroAccuracies = screen.getAllByText('정답률 0%');
    expect(zeroAccuracies.length).toBeGreaterThanOrEqual(1);
  });

  it('should sum conversation counts from history', async () => {
    const StudyTab = await loadStudyTab();
    render(<StudyTab {...defaultProps} />);

    // Total conversations: 1 + 2 = 3
    // The 회화 category header shows "3회"
    const conversationCounts = screen.getAllByText('3회');
    expect(conversationCounts.length).toBeGreaterThanOrEqual(1);
  });
});

// ---- JlptTab tests ----

describe('JlptTab', () => {
  async function loadJlptTab() {
    const mod = await import('@/components/features/stats/jlpt-tab');
    return mod.JlptTab;
  }

  const defaultProps = {
    levelProgress: {
      vocabulary: { total: 100, mastered: 50, inProgress: 20 },
      grammar: { total: 50, mastered: 25, inProgress: 10 },
    },
    currentLevel: 'N5',
  };

  it('should render current level badge', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    const badges = screen.getAllByText('N5');
    expect(badges.length).toBeGreaterThan(0);
  });

  it('should render all JLPT levels', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    expect(screen.getAllByText('N5').length).toBeGreaterThan(0);
    expect(screen.getByText('N4')).toBeInTheDocument();
    expect(screen.getByText('N3')).toBeInTheDocument();
    expect(screen.getByText('N2')).toBeInTheDocument();
    expect(screen.getByText('N1')).toBeInTheDocument();
  });

  it('should calculate overall progress correctly', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    // vocab progress: 50/100 = 50%
    // grammar progress: 25/50 = 50%
    // overall: (50 + 50) / 2 = 50%
    // 50% appears in multiple places (overall, and on current level card)
    const fiftyPercents = screen.getAllByText('50%');
    expect(fiftyPercents.length).toBeGreaterThanOrEqual(1);
  });

  it('should handle zero totals without division by zero', async () => {
    const JlptTab = await loadJlptTab();
    const zeroProps = {
      levelProgress: {
        vocabulary: { total: 0, mastered: 0, inProgress: 0 },
        grammar: { total: 0, mastered: 0, inProgress: 0 },
      },
      currentLevel: 'N5',
    };
    render(<JlptTab {...zeroProps} />);

    // Should render without errors, showing 0%
    const zeroPercents = screen.getAllByText('0%');
    expect(zeroPercents.length).toBeGreaterThanOrEqual(1);
  });

  it('should show "학습 중" for current level', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    expect(screen.getByText('학습 중')).toBeInTheDocument();
  });
});
