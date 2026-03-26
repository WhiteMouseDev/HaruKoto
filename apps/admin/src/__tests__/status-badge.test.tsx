import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { StatusBadge } from '@/components/ui/status-badge';

// Mock next-intl useTranslations
vi.mock('next-intl', () => ({
  useTranslations: (namespace: string) => {
    const translations: Record<string, Record<string, string>> = {
      status: {
        needsReview: 'Needs Review',
        approved: 'Approved',
        rejected: 'Rejected',
      },
    };
    return (key: string) => translations[namespace]?.[key] ?? key;
  },
}));

describe('StatusBadge', () => {
  it('should render needs_review badge with amber color classes', () => {
    const { container } = render(<StatusBadge status="needs_review" />);
    const badge = screen.getByText('Needs Review');
    expect(badge).toBeTruthy();
    expect(badge.className).toContain('bg-amber-100');
    expect(badge.className).toContain('text-amber-700');
    expect(container).toBeTruthy();
  });

  it('should render approved badge with green color classes', () => {
    render(<StatusBadge status="approved" />);
    const badge = screen.getByText('Approved');
    expect(badge).toBeTruthy();
    expect(badge.className).toContain('bg-green-100');
    expect(badge.className).toContain('text-green-700');
  });

  it('should render rejected badge with red color classes', () => {
    render(<StatusBadge status="rejected" />);
    const badge = screen.getByText('Rejected');
    expect(badge).toBeTruthy();
    expect(badge.className).toContain('bg-red-100');
    expect(badge.className).toContain('text-red-700');
  });

  it('should render as a span element', () => {
    const { container } = render(<StatusBadge status="approved" />);
    const span = container.querySelector('span');
    expect(span).toBeTruthy();
  });

  it('should have inline-flex rounded-full classes', () => {
    render(<StatusBadge status="needs_review" />);
    const badge = screen.getByText('Needs Review');
    expect(badge.className).toContain('inline-flex');
    expect(badge.className).toContain('rounded-full');
  });
});
