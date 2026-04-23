import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { NavBadge } from '@/components/layout/sidebar-badge';

describe('NavBadge', () => {
  it('renders null when count is 0', () => {
    const { container } = render(<NavBadge count={0} />);
    expect(container.firstChild).toBeNull();
  });

  it('renders count when count is between 1 and 99', () => {
    render(<NavBadge count={5} />);
    expect(screen.getByText('5')).toBeInTheDocument();
  });

  it('renders 99+ when count exceeds 99', () => {
    render(<NavBadge count={150} />);
    expect(screen.getByText('99+')).toBeInTheDocument();
  });

  it('renders with informational primary-tinted background (not alarm-red)', () => {
    // Per commit f50d797: badge deliberately uses bg-primary/15 + text-primary
    // so the pending count reads as informational, not as an error state.
    render(<NavBadge count={3} />);
    const badge = screen.getByText('3');
    expect(badge.className).toContain('bg-primary/15');
    expect(badge.className).toContain('text-primary');
  });
});
