'use client';

import { Component, type ReactNode } from 'react';
import { Button } from '@/components/ui/button';
import { RefreshCw } from 'lucide-react';
import { FoxMascot } from '@/components/brand/fox-mascot';

type Props = {
  children: ReactNode;
  fallback?: ReactNode;
};

type State = {
  hasError: boolean;
  error: Error | null;
};

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught:', error, errorInfo);
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div className="flex min-h-[50dvh] flex-col items-center justify-center gap-4 p-6 text-center">
          <FoxMascot size={48} />
          <h2 className="text-lg font-semibold">문제가 발생했습니다</h2>
          <p className="text-muted-foreground max-w-sm text-sm">
            예상치 못한 오류가 발생했습니다. 다시 시도해주세요.
          </p>
          <div className="flex gap-2">
            <Button variant="outline" onClick={this.handleReset} className="gap-1.5">
              <RefreshCw className="size-4" />
              다시 시도
            </Button>
            <Button
              variant="ghost"
              onClick={() => {
                window.location.href = '/home';
              }}
            >
              홈으로
            </Button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
