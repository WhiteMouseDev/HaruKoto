'use client';

import { use } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ArrowLeft, RefreshCw, Trophy } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useKanaStages } from '@/hooks/use-kana';
import { KanaStageList } from '@/components/features/kana/kana-stage-list';

type Props = {
  params: Promise<{ type: string }>;
};

export default function KanaStageListPage({ params }: Props) {
  const { type } = use(params);
  const router = useRouter();

  const kanaType = type === 'katakana' ? 'KATAKANA' : 'HIRAGANA';
  const label = kanaType === 'HIRAGANA' ? '히라가나' : '가타카나';

  const { data, isLoading, error, refetch } = useKanaStages(kanaType);

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Header */}
      <div className="flex items-center gap-2 pt-2">
        <Button
          variant="ghost"
          size="icon"
          className="size-8"
          onClick={() => router.push('/study/kana')}
        >
          <ArrowLeft className="size-4" />
        </Button>
        <h1 className="text-2xl font-bold">{label} 학습</h1>
      </div>

      {error ? (
        <div className="flex flex-col items-center justify-center gap-4 p-8">
          <p className="text-muted-foreground text-center">
            {error?.message ?? '데이터를 불러오지 못했습니다.'}
          </p>
          <Button
            variant="outline"
            onClick={() => refetch()}
            className="gap-2"
          >
            <RefreshCw className="size-4" />
            다시 시도
          </Button>
        </div>
      ) : isLoading ? (
        <div className="flex flex-col gap-3">
          <div className="bg-secondary h-6 w-full animate-pulse rounded" />
          {[1, 2, 3, 4].map((n) => (
            <div
              key={n}
              className="bg-secondary h-24 animate-pulse rounded-xl"
            />
          ))}
        </div>
      ) : (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <KanaStageList
            stages={data?.stages ?? []}
            kanaType={kanaType}
            onStageClick={(stageNumber) =>
              router.push(`/study/kana/${type}/stage/${stageNumber}`)
            }
          />
        </motion.div>
      )}

      {/* Quiz CTA */}
      {data?.stages?.some((s) => s.isCompleted) && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="flex flex-col gap-3"
        >
          <Button
            variant="outline"
            className="h-12 w-full rounded-xl"
            onClick={() => router.push(`/study/kana/${type}/quiz?mode=recognition`)}
          >
            {label} 퀴즈 도전하기
          </Button>

          {/* Quiz mode options */}
          <div className="flex flex-col gap-2">
            <h3 className="text-sm font-medium text-muted-foreground">
              퀴즈 모드
            </h3>
            <div className="grid grid-cols-2 gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() =>
                  router.push(`/study/kana/${type}/quiz?mode=recognition`)
                }
              >
                가나 인식
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() =>
                  router.push(`/study/kana/${type}/quiz?mode=sound_matching`)
                }
              >
                발음 매칭
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() =>
                  router.push(`/study/kana/${type}/quiz?mode=kana_matching`)
                }
              >
                히라↔가타 매칭
              </Button>
            </div>
          </div>
        </motion.div>
      )}

      {/* Master Quiz - only when all stages complete */}
      {data?.stages &&
        data.stages.length > 0 &&
        data.stages.every((s) => s.isCompleted) && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
          >
            <Card className="border-primary bg-primary/5">
              <CardContent className="flex flex-col gap-3 p-5">
                <div className="flex items-center gap-3">
                  <Trophy className="text-primary size-6" />
                  <div>
                    <h3 className="font-semibold">{label} 마스터 퀴즈</h3>
                    <p className="text-muted-foreground text-sm">
                      전체 출제 · 90% 이상 통과
                    </p>
                  </div>
                </div>
                <Button
                  className="h-12 rounded-xl"
                  onClick={() =>
                    router.push(
                      `/study/kana/${type}/quiz?mode=recognition&master=true`
                    )
                  }
                >
                  도전하기
                </Button>
              </CardContent>
            </Card>
          </motion.div>
        )}
    </div>
  );
}
