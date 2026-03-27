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

  it('renders with destructive background class', () => {
    render(<NavBadge count={3} />);
    const badge = screen.getByText('3');
    expect(badge.className).toContain('bg-destructive');
  });
});
