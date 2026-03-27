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
    audioUrl: null,
    isLoading: false,
    playingField: null,
    confirmField: null,
    setConfirmField: mockSetConfirmField,
    handlePlayPause: mockHandlePlayPause,
    regenerateMutation: { mutate: mockMutate, isPending: false } as any,
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

  it('renders 1 field row for grammar content type', () => {
    setupHook();
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getByText('Pattern')).toBeTruthy();
    expect(screen.queryByText('Reading')).toBeNull();
  });

  it('shows XCircle icon and generate button when no audio', () => {
    setupHook({ audioUrl: null });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getByText('No audio')).toBeTruthy();
    expect(screen.getByText('Generate')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Play' })).toBeNull();
  });

  it('shows play button when audio present', () => {
    setupHook({ audioUrl: 'https://example.com/audio.mp3' });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getByRole('button', { name: 'Play' })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Regenerate' })).toBeTruthy();
    expect(screen.queryByText('No audio')).toBeNull();
    expect(screen.queryByText('Generate')).toBeNull();
  });

  it('calls setConfirmField when generate button clicked', () => {
    setupHook({ audioUrl: null });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    fireEvent.click(screen.getByText('Generate'));
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
    setupHook({ audioUrl: 'https://example.com/audio.mp3', confirmField: 'pattern' });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    expect(screen.getByTestId('regenerate-dialog')).toBeTruthy();
  });

  it('calls handlePlayPause with field value when play button clicked', () => {
    setupHook({ audioUrl: 'https://example.com/audio.mp3' });
    render(<TtsPlayer contentType="grammar" itemId="g1" itemLabel="Test" />);
    fireEvent.click(screen.getByRole('button', { name: 'Play' }));
    expect(mockHandlePlayPause).toHaveBeenCalledWith('pattern');
  });
});
