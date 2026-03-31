import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock next-intl useTranslations
vi.mock('next-intl', () => ({
  useTranslations: () => {
    return (key: string) => {
      const map: Record<string, string> = {
        'fields.reading': 'Reading',
        'fields.word': 'Word',
        'fields.exampleSentence': 'Example sentence',
        'fields.exampleSentences': 'Example Sentences',
        'fields.pattern': 'Pattern',
        'fields.sentence': 'Sentence',
        'fields.japaneseSentence': 'Japanese sentence',
        'fields.situation': 'Situation',
        noAudio: 'No audio',
        generate: 'Generate',
        play: 'Play',
        pause: 'Pause',
        regenerateTooltip: 'Regenerate',
      };
      return map[key] ?? key;
    };
  },
}));

const mockHandlePlayPause = vi.fn();
const mockSetConfirmField = vi.fn();
const mockMutate = vi.fn();

vi.mock('@/hooks/use-tts-player', () => ({
  useTtsPlayer: vi.fn(),
}));

vi.mock('@/components/content/regenerate-confirm-dialog', () => ({
  RegenerateConfirmDialog: ({ open }: { open: boolean }) =>
    open ? <div data-testid="regenerate-dialog" /> : null,
}));

import { useTtsPlayer } from '@/hooks/use-tts-player';
import { TtsPlayer } from '@/components/content/tts-player';

const mockUseTtsPlayer = vi.mocked(useTtsPlayer);

function setupHook(overrides: Partial<ReturnType<typeof useTtsPlayer>> = {}) {
  mockUseTtsPlayer.mockReturnValue({
    audios: {},
    isLoading: false,
    playingField: null,
    confirmField: null,
    setConfirmField: mockSetConfirmField,
    handlePlayPause: mockHandlePlayPause,
    regenerateMutation: {
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useTtsPlayer>['regenerateMutation'],
    ...overrides,
  });
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe('TtsPlayer', () => {
  it('renders 3 field rows for vocabulary content type', () => {
    setupHook();
    render(<TtsPlayer contentType="vocabulary" itemId="v1" itemLabel="Test" />);
    expect(screen.getByText('Reading')).toBeTruthy();
    expect(screen.getByText('Word')).toBeTruthy();
    expect(screen.getByText('Example sentence')).toBeTruthy();
  });

  it('renders 2 field rows for grammar content type', () => {
    setupHook();
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getByText('Pattern')).toBeTruthy();
    expect(screen.getByText('Example Sentences')).toBeTruthy();
    expect(screen.queryByText('Reading')).toBeNull();
  });

  it('shows XCircle icon and generate button when no audio', () => {
    setupHook({
      audios: { pattern: null, example_sentences: null },
    });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getAllByText('No audio')).toHaveLength(2);
    expect(screen.getAllByText('Generate')).toHaveLength(2);
    expect(screen.queryByRole('button', { name: 'Play' })).toBeNull();
  });

  it('shows play button when audio present for a field', () => {
    setupHook({
      audios: {
        pattern: { audioUrl: 'https://example.com/audio.mp3', provider: 'elevenlabs', createdAt: '2026-01-01T00:00:00Z' },
        example_sentences: { audioUrl: 'https://example.com/audio2.mp3', provider: 'elevenlabs', createdAt: '2026-01-01T00:00:00Z' },
      },
    });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getAllByRole('button', { name: 'Play' })).toHaveLength(2);
    expect(screen.getAllByRole('button', { name: 'Regenerate' })).toHaveLength(2);
    expect(screen.queryByText('No audio')).toBeNull();
    expect(screen.queryByText('Generate')).toBeNull();
  });

  it('calls setConfirmField when generate button clicked', () => {
    setupHook({
      audios: { pattern: null },
    });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    fireEvent.click(screen.getAllByText('Generate')[0]!);
    expect(mockSetConfirmField).toHaveBeenCalledWith('pattern');
  });

  it('does not render Select element', () => {
    setupHook();
    const { container } = render(
      <TtsPlayer contentType="vocabulary" itemId="v1" itemLabel="Test" />,
    );
    expect(container.querySelector('select')).toBeNull();
    expect(container.querySelector('[role="combobox"]')).toBeNull();
  });

  it('renders loading skeleton when isLoading is true', () => {
    setupHook({ isLoading: true });
    const { container } = render(
      <TtsPlayer contentType="vocabulary" itemId="v1" itemLabel="Test" />,
    );
    expect(container.querySelector('.animate-pulse')).not.toBeNull();
    expect(screen.queryByText('Reading')).toBeNull();
  });

  it('opens regenerate dialog when confirmField is set', () => {
    setupHook({
      audios: {
        pattern: { audioUrl: 'https://example.com/audio.mp3', provider: 'elevenlabs', createdAt: '2026-01-01T00:00:00Z' },
      },
      confirmField: 'pattern',
    });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getByTestId('regenerate-dialog')).toBeTruthy();
  });

  it('calls handlePlayPause with field value when play button clicked', () => {
    setupHook({
      audios: {
        pattern: { audioUrl: 'https://example.com/audio.mp3', provider: 'elevenlabs', createdAt: '2026-01-01T00:00:00Z' },
      },
    });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    fireEvent.click(screen.getByRole('button', { name: 'Play' }));
    expect(mockHandlePlayPause).toHaveBeenCalledWith('pattern');
  });

  it('shows CheckCircle2 for field with audio and XCircle for field without audio in same component', () => {
    setupHook({
      audios: {
        reading: { audioUrl: 'https://example.com/reading.mp3', provider: 'elevenlabs', createdAt: '2026-01-01T00:00:00Z' },
        word: null,
        example_sentence: null,
      },
    });
    render(<TtsPlayer contentType="vocabulary" itemId="v1" itemLabel="Test" />);

    // Reading field has audio — should show Play button
    expect(screen.getByRole('button', { name: 'Play' })).toBeTruthy();

    // Word and example_sentence have no audio — should show Generate buttons
    expect(screen.getAllByText('Generate')).toHaveLength(2);
    expect(screen.getAllByText('No audio')).toHaveLength(2);
  });

  it('clicking generate on field without audio opens confirm dialog for that field', () => {
    setupHook({
      audios: {
        reading: { audioUrl: 'https://example.com/reading.mp3', provider: 'elevenlabs', createdAt: '2026-01-01T00:00:00Z' },
        word: null,
        example_sentence: null,
      },
    });
    render(<TtsPlayer contentType="vocabulary" itemId="v1" itemLabel="Test" />);

    // Click the first Generate button (for 'word' field, since reading has audio)
    const generateButtons = screen.getAllByText('Generate');
    fireEvent.click(generateButtons[0]!);
    expect(mockSetConfirmField).toHaveBeenCalledWith('word');
  });
});
