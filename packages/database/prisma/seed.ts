import { PrismaClient, ScenarioCategory, Difficulty } from '@prisma/client';
import { readFileSync } from 'fs';
import { join } from 'path';

const prisma = new PrismaClient();

function loadJson<T>(relativePath: string): T {
  const fullPath = join(__dirname, '..', relativePath);
  return JSON.parse(readFileSync(fullPath, 'utf-8'));
}

async function main() {
  console.log('🌸 Seeding HaruKoto database...');

  // 1. Seed N5 Vocabulary
  const vocabData = loadJson<any[]>('data/vocabulary/n5-words.json');
  const existingVocab = await prisma.vocabulary.count();
  if (existingVocab === 0) {
    await prisma.vocabulary.createMany({
      data: vocabData.map((v) => ({
        word: v.word,
        reading: v.reading,
        meaningKo: v.meaningKo,
        partOfSpeech: v.partOfSpeech,
        jlptLevel: v.jlptLevel,
        exampleSentence: v.exampleSentence,
        exampleReading: v.exampleReading,
        exampleTranslation: v.exampleTranslation,
        tags: v.tags,
        order: v.order,
      })),
    });
    console.log(`✅ ${vocabData.length} N5 vocabulary words seeded`);
  } else {
    console.log(`⏭️ Vocabulary already exists (${existingVocab}), skipping`);
  }

  // 2. Seed N5 Grammar
  const grammarData = loadJson<any[]>('data/grammar/n5-grammar.json');
  const existingGrammar = await prisma.grammar.count();
  if (existingGrammar === 0) {
    await prisma.grammar.createMany({
      data: grammarData.map((g) => ({
        pattern: g.pattern,
        meaningKo: g.meaningKo,
        explanation: g.explanation,
        jlptLevel: g.jlptLevel,
        exampleSentences: g.exampleSentences,
        order: g.order,
      })),
    });
    console.log(`✅ ${grammarData.length} N5 grammar patterns seeded`);
  } else {
    console.log(`⏭️ Grammar already exists (${existingGrammar}), skipping`);
  }

  // 3. Seed Conversation Scenarios
  const scenarios = [
    {
      title: '공항 체크인',
      titleJa: '空港チェックイン',
      description: '공항에서 체크인하는 상황을 연습합니다.',
      category: ScenarioCategory.TRAVEL,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 5,
      keyExpressions: ['チェックインお願いします', 'パスポートをお見せください', '窓側の席をお願いします'],
      situation: '공항 체크인 카운터에서 항공사 직원과 대화합니다.',
      yourRole: '여행객',
      aiRole: '항공사 체크인 직원',
    },
    {
      title: '레스토랑 주문',
      titleJa: 'レストランで注文',
      description: '일본 레스토랑에서 음식을 주문하는 연습을 합니다.',
      category: ScenarioCategory.DAILY,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 5,
      keyExpressions: ['メニューをお願いします', 'これをください', 'お会計お願いします'],
      situation: '일본 레스토랑에 방문하여 주문하고 식사합니다.',
      yourRole: '손님',
      aiRole: '레스토랑 직원',
    },
    {
      title: '편의점 쇼핑',
      titleJa: 'コンビニで買い物',
      description: '편의점에서 물건을 사는 상황을 연습합니다.',
      category: ScenarioCategory.DAILY,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 3,
      keyExpressions: ['袋はいりますか', 'お弁当温めますか', 'ポイントカードはお持ちですか'],
      situation: '일본 편의점에서 물건을 고르고 계산합니다.',
      yourRole: '손님',
      aiRole: '편의점 점원',
    },
    {
      title: '비즈니스 자기소개',
      titleJa: 'ビジネス自己紹介',
      description: '비즈니스 미팅에서 자기소개하는 연습을 합니다.',
      category: ScenarioCategory.BUSINESS,
      difficulty: Difficulty.INTERMEDIATE,
      estimatedMinutes: 5,
      keyExpressions: ['はじめまして', '〜と申します', 'よろしくお願いいたします'],
      situation: '일본 회사와의 비즈니스 미팅에서 자기소개를 합니다.',
      yourRole: '한국 회사 직원',
      aiRole: '일본 회사 직원',
    },
    {
      title: '자유 대화',
      titleJa: 'フリートーク',
      description: '자유롭게 일본어로 대화를 나눠보세요.',
      category: ScenarioCategory.FREE,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 10,
      keyExpressions: [],
      situation: '일본인 친구와 자유롭게 대화합니다.',
      yourRole: '일본어 학습자',
      aiRole: '친근한 일본인 친구',
    },
  ];

  const existingScenarios = await prisma.conversationScenario.count();
  if (existingScenarios === 0) {
    await prisma.conversationScenario.createMany({ data: scenarios });
    console.log(`✅ ${scenarios.length} conversation scenarios seeded`);
  } else {
    console.log(`⏭️ Conversation scenarios already exist (${existingScenarios}), skipping`);
  }

  console.log('🌸 Seeding complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
