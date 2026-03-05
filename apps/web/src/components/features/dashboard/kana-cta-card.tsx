'use client';

import { useRouter } from 'next/navigation';
import { ChevronRight } from 'lucide-react';
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
    <div className="group cursor-pointer overflow-hidden rounded-3xl border border-border bg-card p-6 shadow-sm">
      <div className="relative z-10 flex items-start gap-4">
        <div className="bg-secondary flex size-12 shrink-0 items-center justify-center rounded-full">
          <span className="font-jp text-primary text-xl font-bold">
            {kanaChar}
          </span>
        </div>
        <div className="flex-1">
          <h3 className="mb-1 text-lg font-bold">{label} 배워볼까요?</h3>
          <p className="text-muted-foreground mb-4 text-sm leading-relaxed">
            {description}
          </p>
          <button
            className="bg-primary text-primary-foreground flex w-full items-center justify-center gap-2 rounded-xl py-3.5 font-semibold shadow-sm transition-colors hover:bg-[var(--hk-primary-hover)]"
            onClick={() => router.push('/study/kana')}
          >
            <span>{label} 배우기</span>
            <ChevronRight
              size={18}
              className="transition-transform group-hover:translate-x-1"
            />
          </button>
        </div>
      </div>
    </div>
  );
}
