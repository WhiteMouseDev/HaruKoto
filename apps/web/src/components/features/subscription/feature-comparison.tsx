'use client';

import { Check, X } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

const FEATURES = [
  { name: 'JLPT 단어/문법 학습', free: true, premium: true },
  { name: '퀴즈 무제한', free: true, premium: true },
  { name: '히라가나/가타카나 학습', free: true, premium: true },
  { name: 'AI 채팅 (일 3회)', free: true, premium: false },
  { name: 'AI 채팅 무제한', free: false, premium: true },
  { name: 'AI 음성통화 (일 1회)', free: true, premium: false },
  { name: 'AI 음성통화 무제한', free: false, premium: true },
  { name: '모든 AI 캐릭터 해금', free: false, premium: true },
  { name: '상세 학습 리포트', free: false, premium: true },
  { name: '광고 제거', free: false, premium: true },
] as const;

function FeatureIcon({ enabled }: { enabled: boolean }) {
  return enabled ? (
    <Check className="text-primary size-4" />
  ) : (
    <X className="text-muted-foreground/40 size-4" />
  );
}

export function FeatureComparison() {
  return (
    <Card>
      <CardContent className="p-0">
        {/* Header */}
        <div className="border-b px-4 py-3">
          <div className="grid grid-cols-[1fr_60px_60px] items-center gap-2">
            <span className="text-sm font-bold">기능</span>
            <span className="text-muted-foreground text-center text-xs font-medium">무료</span>
            <span className="text-primary text-center text-xs font-medium">프리미엄</span>
          </div>
        </div>

        {/* Rows */}
        {FEATURES.map((feature, i) => (
          <div
            key={feature.name}
            className={`grid grid-cols-[1fr_60px_60px] items-center gap-2 px-4 py-2.5 ${
              i < FEATURES.length - 1 ? 'border-b' : ''
            }`}
          >
            <span className="text-sm">{feature.name}</span>
            <div className="flex justify-center">
              <FeatureIcon enabled={feature.free} />
            </div>
            <div className="flex justify-center">
              <FeatureIcon enabled={feature.premium} />
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
