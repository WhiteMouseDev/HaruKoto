import { BottomNav } from '@/components/layout/bottom-nav';
import { MainContent } from '@/components/layout/main-content';
import { ErrorBoundary } from '@/components/error-boundary';

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col">
      <ErrorBoundary>
        <MainContent>{children}</MainContent>
      </ErrorBoundary>
      <BottomNav />
    </div>
  );
}
