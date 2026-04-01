import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FilterBar } from '@/components/content/filter-bar';

// Mock next-intl
vi.mock('next-intl', () => ({
  useTranslations: (ns: string) => {
    const keys: Record<string, Record<string, string>> = {
      filter: {
        searchPlaceholder: 'Search...',
        searchLabel: 'Search',
        jlptLabel: 'JLPT Level',
        jlptAll: 'All Levels',
        categoryLabel: 'Category',
        categoryAll: 'All Categories',
        statusLabel: 'Status',
        statusAll: 'All Status',
      },
      status: {
        needsReview: 'Needs Review',
        approved: 'Approved',
        rejected: 'Rejected',
      },
    };
    return (key: string) => keys[ns]?.[key] ?? key;
  },
}));

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({ replace: vi.fn() }),
  usePathname: () => '/vocabulary',
  useSearchParams: () => new URLSearchParams(),
}));

describe('FilterBar accessibility', () => {
  it('search input has an associated label', () => {
    render(<FilterBar />);

    // getByLabelText finds input associated via htmlFor/id
    const searchInput = screen.getByLabelText('Search');
    expect(searchInput).toHaveAttribute('type', 'search');
    expect(searchInput).toHaveAttribute('id', 'search-input');
  });

  it('search label is visually hidden (sr-only)', () => {
    render(<FilterBar />);

    const label = document.querySelector('label[for="search-input"]');
    expect(label).not.toBeNull();
    expect(label?.className).toContain('sr-only');
  });
});
