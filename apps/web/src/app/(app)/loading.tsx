import { Logo } from '@/components/brand/logo';

export default function AppLoading() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-background">
      <div className="flex flex-col items-center gap-3">
        <Logo size="sm" className="animate-pulse" />
      </div>
    </div>
  );
}
