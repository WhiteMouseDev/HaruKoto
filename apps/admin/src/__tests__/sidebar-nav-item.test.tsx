import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';

let mockPathname = '/vocabulary';

vi.mock('next/navigation', () => ({
  usePathname: () => mockPathname,
}));

import { SidebarNavItem } from '@/components/layout/sidebar-nav-item';

describe('SidebarNavItem', () => {
  it('renders badge when badge prop is non-zero', () => {
    mockPathname = '/vocabulary';
    render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" badge={5} />
    );
    expect(screen.getByText('5')).toBeInTheDocument();
  });

  it('does not render badge when badge is 0', () => {
    mockPathname = '/vocabulary';
    render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" badge={0} />
    );
    expect(screen.queryByText('0')).not.toBeInTheDocument();
  });

  it('does not render badge when badge prop is undefined', () => {
    mockPathname = '/vocabulary';
    const { container } = render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" />
    );
    expect(container.querySelector('.bg-destructive')).toBeNull();
  });

  it('sets aria-current="page" when active', () => {
    mockPathname = '/vocabulary';
    render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" />
    );
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('aria-current', 'page');
  });

  it('does not set aria-current when inactive', () => {
    mockPathname = '/dashboard';
    render(
      <SidebarNavItem href="/vocabulary" icon={<span>icon</span>} label="Vocabulary" />
    );
    const link = screen.getByRole('link');
    expect(link).not.toHaveAttribute('aria-current');
  });
});
