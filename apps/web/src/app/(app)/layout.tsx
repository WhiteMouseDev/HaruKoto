import { BottomNav } from '@/components/layout/bottom-nav';
import { ErrorBoundary } from '@/components/error-boundary';

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col">
      <ErrorBoundary>
        <main className="mx-auto w-full max-w-lg flex-1 pb-20">{children}</main>
      </ErrorBoundary>
      <BottomNav />
    </div>
  );
}
