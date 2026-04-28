import type { PricingPlan } from '@/types/subscription';

// 가격 (원)
export const PRICES = {
  MONTHLY: 4900,
  YEARLY: 39900, // 월 3,325원 (32% 할인)
} as const;

// AI 사용량 제한
export const AI_LIMITS = {
  FREE: {
    CHAT_COUNT: 3, // 하루 3회
    CHAT_SECONDS: 300, // 5분
    CALL_COUNT: 30, // 짧은 재시도 폭주 방지
    CALL_SECONDS: 900, // 15분
  },
  PREMIUM: {
    CHAT_COUNT: 50,
    CHAT_SECONDS: 600, // 10분
    CALL_COUNT: 300, // 짧은 재시도 폭주 방지
    CALL_SECONDS: 7200, // 120분
  },
} as const;

// 플랜 정보
export const PRICING_PLANS: PricingPlan[] = [
  {
    id: 'free',
    name: '무료',
    price: 0,
    period: '',
    features: [
      'JLPT 단어/문법 학습',
      '퀴즈 무제한',
      `AI 채팅 하루 ${AI_LIMITS.FREE.CHAT_COUNT}회`,
      'AI 통화 하루 15분',
      '기본 캐릭터 2명',
    ],
  },
  {
    id: 'monthly',
    name: '월간 프리미엄',
    price: PRICES.MONTHLY,
    period: '월',
    recommended: true,
    features: [
      'AI 채팅 하루 50회',
      'AI 통화 하루 120분',
      '모든 캐릭터 해금',
      '상세 학습 리포트',
      '광고 제거',
    ],
  },
  {
    id: 'yearly',
    name: '연간 프리미엄',
    price: PRICES.YEARLY,
    originalPrice: PRICES.MONTHLY * 12,
    period: '년',
    features: [
      '월간 프리미엄의 모든 기능',
      '32% 할인 (월 3,325원)',
    ],
  },
];

// 구독 기간 계산
export function getSubscriptionPeriodEnd(plan: 'monthly' | 'yearly', from: Date = new Date()): Date {
  const end = new Date(from);
  if (plan === 'monthly') {
    end.setMonth(end.getMonth() + 1);
  } else {
    end.setFullYear(end.getFullYear() + 1);
  }
  return end;
}
