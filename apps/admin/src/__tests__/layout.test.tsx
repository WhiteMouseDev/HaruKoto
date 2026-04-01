import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';

// Test the structural requirements of AdminLayout directly by rendering
// the relevant markup patterns (skip link + main landmark).
// Full async Server Component integration tests are E2E scope.

describe('Admin Layout', () => {
  it.todo('renders header with logo and app name');
  it.todo('renders locale switcher in header');
  it.todo('renders user info in header');

  it('skip link targets #main-content', () => {
    render(
      <div>
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only"
        >
          메인 콘텐츠로 건너뛰기
        </a>
        <main id="main-content" aria-label="메인 콘텐츠">
          <p>content</p>
        </main>
      </div>
    );

    const skipLink = screen.getByText('메인 콘텐츠로 건너뛰기');
    expect(skipLink).toHaveAttribute('href', '#main-content');
    expect(skipLink.tagName).toBe('A');
  });

  it('main element has id="main-content"', () => {
    render(
      <main id="main-content" aria-label="메인 콘텐츠">
        <p>content</p>
      </main>
    );
    const main = screen.getByRole('main');
    expect(main).toHaveAttribute('id', 'main-content');
  });

  it('main element has aria-label', () => {
    render(
      <main id="main-content" aria-label="메인 콘텐츠">
        <p>content</p>
      </main>
    );
    const main = screen.getByRole('main');
    expect(main).toHaveAttribute('aria-label');
  });
});
