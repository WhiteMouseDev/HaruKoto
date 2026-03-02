import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default function LandingPage() {
  return (
    <div className="from-background to-secondary flex min-h-dvh flex-col items-center justify-center bg-gradient-to-b px-6">
      {/* Logo & Mascot */}
      <div className="flex flex-col items-center gap-4">
        <div className="text-6xl">🌸</div>
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight">하루코토</h1>
          <p className="font-jp text-muted-foreground mt-1 text-lg">ハルコト</p>
        </div>
        <p className="text-muted-foreground mt-2 text-center">
          매일 한 단어, 봄처럼 피어나는
          <br />
          나의 일본어
        </p>
      </div>

      {/* Auth Buttons */}
      <div className="mt-12 flex w-full max-w-xs flex-col gap-3">
        <Button size="lg" className="h-12 w-full rounded-xl text-base" asChild>
          <Link href="/home">시작하기</Link>
        </Button>
        <Button
          variant="outline"
          size="lg"
          className="h-12 w-full rounded-xl text-base"
          asChild
        >
          <Link href="/home">이미 계정이 있나요? 로그인</Link>
        </Button>
      </div>
    </div>
  );
}
