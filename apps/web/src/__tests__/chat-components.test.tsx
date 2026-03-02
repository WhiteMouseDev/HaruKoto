import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';

// Mock framer-motion
vi.mock('framer-motion', () => ({
  motion: {
    div: (props: React.ComponentProps<'div'>) => <div {...props} />,
    span: (props: React.ComponentProps<'span'>) => <span {...props} />,
    ul: (props: React.ComponentProps<'ul'>) => <ul {...props} />,
    li: (props: React.ComponentProps<'li'>) => <li {...props} />,
  },
  AnimatePresence: ({ children }: React.PropsWithChildren) => <>{children}</>,
}));

// ---- ChatMessage tests ----

describe('ChatMessage', () => {
  async function loadChatMessage() {
    const mod = await import('@/components/features/chat/chat-message');
    return mod.ChatMessage;
  }

  it('should render AI message with translation', async () => {
    const ChatMessage = await loadChatMessage();
    render(
      <ChatMessage
        role="ai"
        messageJa="こんにちは"
        messageKo="안녕하세요"
        showTranslation={true}
      />
    );

    expect(screen.getByText('こんにちは')).toBeInTheDocument();
    expect(screen.getByText('안녕하세요')).toBeInTheDocument();
    expect(screen.getByText('AI')).toBeInTheDocument();
  });

  it('should hide translation when showTranslation is false', async () => {
    const ChatMessage = await loadChatMessage();
    render(
      <ChatMessage
        role="ai"
        messageJa="こんにちは"
        messageKo="안녕하세요"
        showTranslation={false}
      />
    );

    expect(screen.getByText('こんにちは')).toBeInTheDocument();
    expect(screen.queryByText('안녕하세요')).not.toBeInTheDocument();
  });

  it('should render user message without AI label', async () => {
    const ChatMessage = await loadChatMessage();
    render(
      <ChatMessage
        role="user"
        messageJa="はい、そうです"
        showTranslation={true}
      />
    );

    expect(screen.getByText('はい、そうです')).toBeInTheDocument();
    expect(screen.queryByText('AI')).not.toBeInTheDocument();
  });

  it('should show feedback toggle for user messages with feedback', async () => {
    const ChatMessage = await loadChatMessage();
    const feedback = [
      {
        type: 'grammar',
        original: 'そうです',
        correction: 'そうですね',
        explanationKo: 'ね를 붙이면 더 자연스럽습니다.',
      },
    ];
    render(
      <ChatMessage
        role="user"
        messageJa="はい、そうです"
        feedback={feedback}
        showTranslation={true}
      />
    );

    expect(screen.getByText('교정 1건')).toBeInTheDocument();
  });

  it('should toggle feedback display on click', async () => {
    const ChatMessage = await loadChatMessage();
    const feedback = [
      {
        type: 'grammar',
        original: 'そうです',
        correction: 'そうですね',
        explanationKo: 'ね를 붙이면 더 자연스럽습니다.',
      },
    ];
    render(
      <ChatMessage
        role="user"
        messageJa="はい、そうです"
        feedback={feedback}
        showTranslation={true}
      />
    );

    // Initially feedback details are hidden
    expect(screen.queryByText('→ そうですね')).not.toBeInTheDocument();

    // Click to expand
    fireEvent.click(screen.getByText('교정 1건'));
    expect(screen.getByText('→ そうですね')).toBeInTheDocument();
    expect(
      screen.getByText('ね를 붙이면 더 자연스럽습니다.')
    ).toBeInTheDocument();
  });

  it('should not show feedback toggle for AI messages', async () => {
    const ChatMessage = await loadChatMessage();
    render(
      <ChatMessage
        role="ai"
        messageJa="こんにちは"
        feedback={[]}
        showTranslation={true}
      />
    );

    expect(screen.queryByText(/교정/)).not.toBeInTheDocument();
  });
});

// ---- ChatInput tests ----

describe('ChatInput', () => {
  async function loadChatInput() {
    const mod = await import('@/components/features/chat/chat-input');
    return mod.ChatInput;
  }

  it('should render input and buttons', async () => {
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={vi.fn()}
        onHint={vi.fn()}
        hint={null}
        disabled={false}
      />
    );

    expect(
      screen.getByPlaceholderText('일본어로 입력하세요...')
    ).toBeInTheDocument();
  });

  it('should call onSend with trimmed message on Enter', async () => {
    const onSend = vi.fn();
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={onSend}
        onHint={vi.fn()}
        hint={null}
        disabled={false}
      />
    );

    const input = screen.getByPlaceholderText('일본어로 입력하세요...');
    fireEvent.change(input, { target: { value: 'こんにちは' } });
    fireEvent.keyDown(input, { key: 'Enter' });

    expect(onSend).toHaveBeenCalledWith('こんにちは');
  });

  it('should not call onSend for empty message', async () => {
    const onSend = vi.fn();
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={onSend}
        onHint={vi.fn()}
        hint={null}
        disabled={false}
      />
    );

    const input = screen.getByPlaceholderText('일본어로 입력하세요...');
    fireEvent.keyDown(input, { key: 'Enter' });

    expect(onSend).not.toHaveBeenCalled();
  });

  it('should not call onSend when disabled', async () => {
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={vi.fn()}
        onHint={vi.fn()}
        hint={null}
        disabled={true}
      />
    );

    const input = screen.getByPlaceholderText('일본어로 입력하세요...');
    expect(input).toBeDisabled();
  });

  it('should display hint when provided', async () => {
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={vi.fn()}
        onHint={vi.fn()}
        hint="はじめまして"
        disabled={false}
      />
    );

    expect(screen.getByText('はじめまして')).toBeInTheDocument();
  });

  it('should not display hint section when null', async () => {
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={vi.fn()}
        onHint={vi.fn()}
        hint={null}
        disabled={false}
      />
    );

    expect(screen.queryByText('はじめまして')).not.toBeInTheDocument();
  });

  it('should clear input after sending', async () => {
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={vi.fn()}
        onHint={vi.fn()}
        hint={null}
        disabled={false}
      />
    );

    const input = screen.getByPlaceholderText(
      '일본어로 입력하세요...'
    ) as HTMLTextAreaElement;
    fireEvent.change(input, { target: { value: 'テスト' } });
    fireEvent.keyDown(input, { key: 'Enter' });

    expect(input.value).toBe('');
  });

  it('should allow newline with Shift+Enter', async () => {
    const onSend = vi.fn();
    const ChatInput = await loadChatInput();
    render(
      <ChatInput
        onSend={onSend}
        onHint={vi.fn()}
        hint={null}
        disabled={false}
      />
    );

    const input = screen.getByPlaceholderText('일본어로 입력하세요...');
    fireEvent.change(input, { target: { value: 'テスト' } });
    fireEvent.keyDown(input, { key: 'Enter', shiftKey: true });

    // Should NOT call onSend with Shift+Enter
    expect(onSend).not.toHaveBeenCalled();
  });
});

// ---- FeedbackScores tests ----

describe('FeedbackScores', () => {
  async function loadFeedbackScores() {
    const mod = await import('@/components/features/chat/feedback-scores');
    return mod.FeedbackScores;
  }

  const defaultProps = {
    overallScore: 80,
    fluency: 75,
    accuracy: 85,
    vocabularyDiversity: 70,
    naturalness: 90,
  };

  it('should render score labels', async () => {
    const FeedbackScores = await loadFeedbackScores();
    render(<FeedbackScores {...defaultProps} />);

    expect(screen.getByText(/유창성/)).toBeInTheDocument();
    expect(screen.getByText(/정확성/)).toBeInTheDocument();
    expect(screen.getByText(/어휘 다양성/)).toBeInTheDocument();
    expect(screen.getByText(/자연스러움/)).toBeInTheDocument();
  });

  it('should display individual score percentages', async () => {
    const FeedbackScores = await loadFeedbackScores();
    render(<FeedbackScores {...defaultProps} />);

    expect(screen.getByText('75%')).toBeInTheDocument();
    expect(screen.getByText('85%')).toBeInTheDocument();
    expect(screen.getByText('70%')).toBeInTheDocument();
    expect(screen.getByText('90%')).toBeInTheDocument();
  });

  it('should calculate star rating correctly', async () => {
    const FeedbackScores = await loadFeedbackScores();
    render(<FeedbackScores {...defaultProps} />);

    // overallScore=80, starRating = Math.round((80/100)*5*10)/10 = 4.0
    expect(screen.getByText('4.0 / 5')).toBeInTheDocument();
  });

  it('should show encouraging message for high score', async () => {
    const FeedbackScores = await loadFeedbackScores();
    render(<FeedbackScores {...defaultProps} />);

    expect(
      screen.getByText('일본어 실력이 훌륭해요!')
    ).toBeInTheDocument();
  });

  it('should show moderate message for mid score', async () => {
    const FeedbackScores = await loadFeedbackScores();
    render(<FeedbackScores {...{ ...defaultProps, overallScore: 60 }} />);

    expect(
      screen.getByText('일본어 실력이 늘고 있어요!')
    ).toBeInTheDocument();
  });

  it('should show practice message for low score', async () => {
    const FeedbackScores = await loadFeedbackScores();
    render(<FeedbackScores {...{ ...defaultProps, overallScore: 30 }} />);

    expect(screen.getByText('조금 더 연습해봐요!')).toBeInTheDocument();
  });
});

// ---- FeedbackDetails tests ----

describe('FeedbackDetails', () => {
  async function loadFeedbackDetails() {
    const mod = await import('@/components/features/chat/feedback-details');
    return mod.FeedbackDetails;
  }

  it('should render strengths section', async () => {
    const FeedbackDetails = await loadFeedbackDetails();
    render(
      <FeedbackDetails
        strengths={['적절한 경어 사용', '자연스러운 인사']}
        improvements={[]}
        recommendedExpressions={[]}
        vocabulary={[]}
      />
    );

    expect(screen.getByText('잘한 표현')).toBeInTheDocument();
    expect(screen.getByText('적절한 경어 사용')).toBeInTheDocument();
    expect(screen.getByText('자연스러운 인사')).toBeInTheDocument();
  });

  it('should render improvements section', async () => {
    const FeedbackDetails = await loadFeedbackDetails();
    render(
      <FeedbackDetails
        strengths={[]}
        improvements={['조사 사용 연습 필요']}
        recommendedExpressions={[]}
        vocabulary={[]}
      />
    );

    expect(screen.getByText('개선 포인트')).toBeInTheDocument();
    expect(screen.getByText('조사 사용 연습 필요')).toBeInTheDocument();
  });

  it('should render vocabulary section', async () => {
    const FeedbackDetails = await loadFeedbackDetails();
    render(
      <FeedbackDetails
        strengths={[]}
        improvements={[]}
        recommendedExpressions={[]}
        vocabulary={[
          { word: '食べる', reading: 'たべる', meaningKo: '먹다' },
        ]}
      />
    );

    expect(screen.getByText(/새로 배운 표현/)).toBeInTheDocument();
    expect(screen.getByText('食べる')).toBeInTheDocument();
    expect(screen.getByText(/たべる/)).toBeInTheDocument();
    expect(screen.getByText('먹다')).toBeInTheDocument();
  });

  it('should hide sections with empty arrays', async () => {
    const FeedbackDetails = await loadFeedbackDetails();
    render(
      <FeedbackDetails
        strengths={[]}
        improvements={[]}
        recommendedExpressions={[]}
        vocabulary={[]}
      />
    );

    expect(screen.queryByText('잘한 표현')).not.toBeInTheDocument();
    expect(screen.queryByText('개선 포인트')).not.toBeInTheDocument();
    expect(screen.queryByText('추천 표현')).not.toBeInTheDocument();
    expect(screen.queryByText('새로 배운 표현')).not.toBeInTheDocument();
  });

  it('should render recommended expressions', async () => {
    const FeedbackDetails = await loadFeedbackDetails();
    render(
      <FeedbackDetails
        strengths={[]}
        improvements={[]}
        recommendedExpressions={['お疲れ様です', 'よろしくお願いします']}
        vocabulary={[]}
      />
    );

    expect(screen.getByText('추천 표현')).toBeInTheDocument();
    expect(screen.getByText('お疲れ様です')).toBeInTheDocument();
    expect(screen.getByText('よろしくお願いします')).toBeInTheDocument();
  });
});

// ---- TypingIndicator tests ----

describe('TypingIndicator', () => {
  it('should render three dots', async () => {
    const mod = await import('@/components/features/chat/typing-indicator');
    const { container } = render(<mod.TypingIndicator />);

    const dots = container.querySelectorAll('[class*="rounded-full"]');
    expect(dots.length).toBe(3);
  });
});

// ---- CategoryGrid tests ----

describe('CategoryGrid', () => {
  async function loadCategoryGrid() {
    const mod = await import('@/components/features/chat/category-grid');
    return mod.CategoryGrid;
  }

  it('should render all 4 categories', async () => {
    const CategoryGrid = await loadCategoryGrid();
    render(<CategoryGrid onSelect={vi.fn()} />);

    expect(screen.getByText('여행')).toBeInTheDocument();
    expect(screen.getByText('일상')).toBeInTheDocument();
    expect(screen.getByText('비즈니스')).toBeInTheDocument();
    expect(screen.getByText('자유주제')).toBeInTheDocument();
  });

  it('should call onSelect with category id on click', async () => {
    const onSelect = vi.fn();
    const CategoryGrid = await loadCategoryGrid();
    render(<CategoryGrid onSelect={onSelect} />);

    fireEvent.click(screen.getByText('여행'));
    expect(onSelect).toHaveBeenCalledWith('TRAVEL');
  });
});
