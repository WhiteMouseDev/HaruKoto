'use client';

import { useRouter } from 'next/navigation';
import { ArrowRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useKanaProgress } from '@/hooks/use-kana';

export function KanaCtaCard() {
  const router = useRouter();
  const { data: progress } = useKanaProgress();

  const hiraganaDone = progress && progress.hiragana.pct >= 100;
  const katakanaDone = progress && progress.katakana.pct >= 100;

  if (hiraganaDone && katakanaDone) return null;

  const showKatakana = hiraganaDone && !katakanaDone;
  const label = showKatakana ? '가타카나' : '히라가나';
  const kanaChar = showKatakana ? 'ア' : 'あ';
  const description = showKatakana
    ? '히라가나를 마스터했어요! 이제 가타카나를 배워볼까요?'
    : '일본어의 기본! 히라가나 46자를 배우면 단어 학습을 시작할 수 있어요.';

  return (
    <Card className="border-primary/30 bg-primary/5">
      <CardContent className="flex flex-col gap-3 p-5">
        <div className="flex items-center gap-3">
          <div className="bg-primary/10 flex size-10 items-center justify-center rounded-xl">
            <span className="font-jp text-primary text-lg font-bold">{kanaChar}</span>
          </div>
          <div className="flex-1">
            <h3 className="font-semibold">{label} 배워볼까요?</h3>
            <p className="text-muted-foreground text-xs">{description}</p>
          </div>
        </div>
        <Button
          className="h-10 rounded-xl"
          onClick={() => router.push('/study/kana')}
        >
          {label} 배우기
          <ArrowRight className="ml-1 size-4" />
        </Button>
      </CardContent>
    </Card>
  );
}
