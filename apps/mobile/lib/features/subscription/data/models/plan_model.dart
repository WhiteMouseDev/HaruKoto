class PricingPlan {
  final String id;
  final String name;
  final int price;
  final int? originalPrice;
  final String period;
  final List<String> features;
  final bool recommended;

  const PricingPlan({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.period,
    required this.features,
    this.recommended = false,
  });
}

const pricingPlans = <PricingPlan>[
  PricingPlan(
    id: 'free',
    name: '무료',
    price: 0,
    period: '',
    features: [
      'JLPT 단어/문법 학습',
      '퀴즈 무제한',
      'AI 채팅 하루 3회',
      'AI 통화 하루 15분',
      '기본 캐릭터 2명',
    ],
  ),
  PricingPlan(
    id: 'monthly',
    name: '월간 프리미엄',
    price: 4900,
    period: '월',
    recommended: true,
    features: [
      'AI 채팅 하루 50회',
      'AI 통화 하루 120분',
      '모든 캐릭터 해금',
      '상세 학습 리포트',
      '광고 제거',
    ],
  ),
  PricingPlan(
    id: 'yearly',
    name: '연간 프리미엄',
    price: 39900,
    originalPrice: 58800,
    period: '년',
    features: [
      '월간 프리미엄의 모든 기능',
      '32% 할인 (월 3,325원)',
    ],
  ),
];
