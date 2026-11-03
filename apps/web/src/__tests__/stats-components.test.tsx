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
    // The current stats contract exposes vocabulary and grammar, not kanji.
    expect(screen.queryByText('한자')).not.toBeInTheDocument();
    expect(screen.getByText('회화')).toBeInTheDocument();
  });

  it('should calculate accuracy correctly', async () => {
    const StudyTab = await loadStudyTab();
    render(<StudyTab {...defaultProps} />);

    // Cumulative saved history: (4 + 8) / (5 + 10) = 80%.
    expect(screen.getByText('정답률').parentElement).toHaveTextContent('80%');
  });

  it('should handle zero totalAnswers without division by zero', async () => {
    const StudyTab = await loadStudyTab();
    const zeroProps = {
      ...defaultProps,
      historyRecords: defaultProps.historyRecords.map((record) => ({
        ...record,
        totalAnswers: 0,
        correctAnswers: 0,
      })),
    };
    render(<StudyTab {...zeroProps} />);

    expect(screen.getByText('정답률').parentElement).toHaveTextContent('0%');
    expect(screen.queryByText(/NaN|Infinity/)).not.toBeInTheDocument();
  });

  it('should sum conversation counts from history', async () => {
    const StudyTab = await loadStudyTab();
    render(<StudyTab {...defaultProps} />);

    // Total conversations: 1 + 2 = 3
    // The 회화 category header shows "3회"
    const conversationCounts = screen.getAllByText('3회');
    expect(conversationCounts.length).toBeGreaterThanOrEqual(1);
  });

  it('weights cumulative accuracy by saved answers instead of averaging days', async () => {
    const StudyTab = await loadStudyTab();
    render(
      <StudyTab
        {...defaultProps}
        historyRecords={[
          {
            ...defaultProps.historyRecords[0],
            correctAnswers: 1,
            totalAnswers: 1,
          },
          {
            ...defaultProps.historyRecords[1],
            correctAnswers: 1,
            totalAnswers: 9,
          },
        ]}
      />
    );
    expect(screen.getByText('정답률').parentElement).toHaveTextContent('20%');
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

  it('shows the current and next level instead of unrelated level progress', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    expect(screen.getAllByText('N5').length).toBeGreaterThan(0);
    expect(screen.getByText('N4')).toBeInTheDocument();
    for (const level of ['N3', 'N2', 'N1']) {
      expect(screen.queryByText(level)).not.toBeInTheDocument();
    }
  });

  it('should calculate overall progress correctly', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    // Weighted mastered items: (50 + 25) / (100 + 50) = 50%.
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

  it('shows actual current-level mastery counts without claiming completion', async () => {
    const JlptTab = await loadJlptTab();
    render(<JlptTab {...defaultProps} />);

    expect(screen.getByText('기초 일본어')).toBeInTheDocument();
    expect(screen.getByText(/마스터 75 \/ 150개/)).toBeInTheDocument();
    expect(screen.queryByText('N5 완전 마스터!')).not.toBeInTheDocument();
  });

  it('weights mastery by actual item counts when category sizes differ', async () => {
    const JlptTab = await loadJlptTab();
    render(
      <JlptTab
        currentLevel="N5"
        levelProgress={{
          vocabulary: { total: 100, mastered: 40, inProgress: 0 },
          grammar: { total: 50, mastered: 5, inProgress: 0 },
        }}
      />
    );
    expect(screen.getByText('30%')).toBeInTheDocument();
  });

  it('shows completed N1 without advertising a nonexistent next level', async () => {
    const JlptTab = await loadJlptTab();
    render(
      <JlptTab
        currentLevel="N1"
        levelProgress={{
          vocabulary: { total: 100, mastered: 100, inProgress: 0 },
          grammar: { total: 50, mastered: 50, inProgress: 0 },
        }}
      />
    );
    expect(screen.getByText('N1 완전 마스터!')).toBeInTheDocument();
    expect(screen.queryByText(/다음 목표:/)).not.toBeInTheDocument();
  });
});
