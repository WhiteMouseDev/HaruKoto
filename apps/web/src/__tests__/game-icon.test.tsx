import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { GameIcon } from '@/components/ui/game-icon';

describe('GameIcon', () => {
  it('should render a known icon', () => {
    const { container } = render(<GameIcon name="trophy" />);
    // lucide-react renders an <svg> element
    const svg = container.querySelector('svg');
    expect(svg).not.toBeNull();
  });

  it('should apply className to the icon', () => {
    const { container } = render(
      <GameIcon name="trophy" className="size-5 text-red-500" />
    );
    const svg = container.querySelector('svg');
    expect(svg?.getAttribute('class')).toContain('size-5');
    expect(svg?.getAttribute('class')).toContain('text-red-500');
  });

  it('should render fallback HelpCircle for unknown icon name', () => {
    const { container } = render(<GameIcon name="nonexistent-icon" />);
    const svg = container.querySelector('svg');
    expect(svg).not.toBeNull();
  });

  it('should render fallback for empty string', () => {
    const { container } = render(<GameIcon name="" />);
    const svg = container.querySelector('svg');
    expect(svg).not.toBeNull();
  });

  it('should render different SVGs for different icon names', () => {
    const { container: c1 } = render(<GameIcon name="trophy" />);
    const { container: c2 } = render(<GameIcon name="flame" />);

    const svg1 = c1.querySelector('svg')?.innerHTML;
    const svg2 = c2.querySelector('svg')?.innerHTML;
    expect(svg1).not.toBe(svg2);
  });

  it('should render all gamification icon names without errors', () => {
    const iconNames = [
      'target',
      'file-text',
      'library',
      'trophy',
      'check-check',
      'message-circle',
      'messages-square',
      'mic',
      'flame',
      'zap',
      'sparkles',
      'crown',
      'book-open',
      'book-marked',
      'star',
      'moon',
      'flower-2',
      'gem',
      'medal',
      'award',
      'party-popper',
      'megaphone',
    ];

    for (const name of iconNames) {
      const { container } = render(<GameIcon name={name} />);
      const svg = container.querySelector('svg');
      expect(svg, `Icon "${name}" should render an SVG`).not.toBeNull();
    }
  });
});
