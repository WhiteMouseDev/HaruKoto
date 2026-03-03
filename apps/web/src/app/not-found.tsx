import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default function NotFound() {
  return (
    <div className="flex min-h-[50dvh] flex-col items-center justify-center gap-4 p-6 text-center">
      <span className="text-4xl">🦊</span>
      <h2 className="text-lg font-semibold">페이지를 찾을 수 없습니다</h2>
      <p className="text-muted-foreground max-w-sm text-sm">
        요청하신 페이지가 존재하지 않거나 이동되었습니다.
      </p>
      <Button variant="outline" asChild>
        <Link href="/home">홈으로</Link>
      </Button>
    </div>
  );
}
