import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';

vi.mock('next/navigation', () => ({
  usePathname: () => '/vocabulary',
}));

import { SidebarNavItem } from '@/components/layout/sidebar-nav-item';

describe('SidebarNavItem', () => {
  it('renders badge when badge prop is non-zero', () => {
    render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" badge={5} />
    );
    expect(screen.getByText('5')).toBeInTheDocument();
  });

  it('does not render badge when badge is 0', () => {
    render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" badge={0} />
    );
    expect(screen.queryByText('0')).not.toBeInTheDocument();
  });

  it('does not render badge when badge prop is undefined', () => {
    const { container } = render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" />
    );
    expect(container.querySelector('.bg-destructive')).toBeNull();
  });
});
