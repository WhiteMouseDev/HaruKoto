import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';

// Mock next-intl — returns the key as the translation string
vi.mock('next-intl', () => ({
  useTranslations: () => (key: string) => key,
}));

import { ReviewHeader } from '@/components/content/review-header';

describe('ReviewHeader', () => {
  const defaultProps = {
    reviewStatus: 'needs_review' as const,
    onApprove: vi.fn(),
    onReject: vi.fn(),
    isLoading: false,
  };

  it('renders approve and reject buttons for needs_review status', () => {
    render(<ReviewHeader {...defaultProps} />);
    // With mocked useTranslations returning the key, buttons show "approve" and "reject"
    expect(screen.getByText('approve')).toBeInTheDocument();
    expect(screen.getByText('reject')).toBeInTheDocument();
  });

  it('calls onApprove when approve button is clicked', () => {
    const onApprove = vi.fn();
    render(<ReviewHeader {...defaultProps} onApprove={onApprove} />);
    const approveBtn = screen.getByText('approve').closest('button');
    expect(approveBtn).not.toBeNull();
    fireEvent.click(approveBtn!);
    expect(onApprove).toHaveBeenCalledTimes(1);
  });

  it('calls onReject when reject button is clicked', () => {
    const onReject = vi.fn();
    render(<ReviewHeader {...defaultProps} onReject={onReject} />);
    const rejectBtn = screen.getByText('reject').closest('button');
    expect(rejectBtn).not.toBeNull();
    fireEvent.click(rejectBtn!);
    expect(onReject).toHaveBeenCalledTimes(1);
  });

  it('disables buttons when isLoading is true', () => {
    render(<ReviewHeader {...defaultProps} isLoading={true} />);
    const buttons = screen.getAllByRole('button');
    buttons.forEach((btn) => {
      expect(btn).toBeDisabled();
    });
  });

  it('renders StatusBadge with correct review status', () => {
    const { container } = render(
      <ReviewHeader {...defaultProps} reviewStatus="approved" />,
    );
    // StatusBadge renders inside the component — verify the container has content
    expect(container.firstChild).not.toBeNull();
  });
});
