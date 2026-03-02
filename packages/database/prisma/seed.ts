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
      title: '호텔 체크인',
      titleJa: 'ホテルチェックイン',
      description: '일본 호텔에서 체크인하는 상황을 연습합니다.',
      category: ScenarioCategory.TRAVEL,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 5,
      keyExpressions: [
        'チェックインお願いします',
        '予約した〜です',
        '鍵をお願いします',
      ],
      situation: '일본 호텔 프론트에서 체크인합니다.',
      yourRole: '여행객 (호텔 손님)',
      aiRole: '호텔 프론트 직원',
      systemPrompt: `## シナリオ: ホテルチェックイン
あなたは日本のホテルのフロントスタッフです。
- 丁寧な敬語を使ってください
- チェックインの流れ: 名前確認 → 予約確認 → 部屋の説明 → 鍵の受け渡し
- ユーザーが困っている場合は、優しくリードしてください
- 朝食の時間やWi-Fiのパスワードなど、実用的な情報も提供してください`,
      order: 1,
    },
    {
      title: '편의점에서',
      titleJa: 'コンビニで買い物',
      description: '일본 편의점에서 물건을 사는 상황을 연습합니다.',
      category: ScenarioCategory.DAILY,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 3,
      keyExpressions: [
        '袋はいりますか',
        'お弁当温めますか',
        'ポイントカードはお持ちですか',
      ],
      situation: '일본 편의점에서 물건을 고르고 계산합니다.',
      yourRole: '손님',
      aiRole: '편의점 점원',
      systemPrompt: `## シナリオ: コンビニで買い物
あなたは日本のコンビニの店員です。
- 「いらっしゃいませ」から始めてください
- よくある質問: 袋、お弁当の温め、ポイントカード、お箸・スプーン
- 会計の流れを自然に進めてください
- 丁寧だが親しみやすい接客をしてください`,
      order: 2,
    },
    {
      title: '자기소개',
      titleJa: '自己紹介',
      description: '새로운 사람을 만나 자기소개하는 연습을 합니다.',
      category: ScenarioCategory.DAILY,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 5,
      keyExpressions: ['はじめまして', '〜と言います', 'よろしくお願いします'],
      situation: '일본어 교실에서 새로운 친구를 만나 자기소개합니다.',
      yourRole: '일본어 학습자',
      aiRole: '일본어 교실의 일본인 학생',
      systemPrompt: `## シナリオ: 自己紹介
あなたは日本語教室の日本人学生です。
- 自己紹介から始めてください（名前、趣味、出身など）
- ユーザーにも自己紹介を促してください
- 共通の趣味があれば話を広げてください
- カジュアルだが丁寧な話し方をしてください（です/ます形）`,
      order: 3,
    },
    {
      title: '레스토랑 주문',
      titleJa: 'レストランで注文',
      description: '일본 레스토랑에서 음식을 주문하는 연습을 합니다.',
      category: ScenarioCategory.TRAVEL,
      difficulty: Difficulty.BEGINNER,
      estimatedMinutes: 5,
      keyExpressions: [
        'メニューをお願いします',
        'これをください',
        'お会計お願いします',
      ],
      situation: '일본 레스토랑에 방문하여 주문하고 식사합니다.',
      yourRole: '손님',
      aiRole: '레스토랑 직원',
      systemPrompt: `## シナリオ: レストランで注文
あなたは日本のレストランの店員です。
- 「いらっしゃいませ、何名様ですか？」から始めてください
- メニューの説明、おすすめ料理の提案をしてください
- 注文の流れ: 人数確認 → 席案内 → メニュー → 注文 → 食事 → 会計
- アレルギーの確認なども自然に行ってください`,
      order: 4,
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
      systemPrompt: `## シナリオ: フリートーク
あなたはユーザーの日本人の友達です。
- フレンドリーで親しみやすい話し方をしてください
- ユーザーの興味に合わせて話題を変えてください
- 日本の文化、食べ物、アニメ、旅行など幅広い話題に対応してください
- カジュアルですが、ユーザーのレベルに合わせた表現を使ってください`,
      order: 5,
    },
  ];

  const existingScenarios = await prisma.conversationScenario.count();
  if (existingScenarios === 0) {
    await prisma.conversationScenario.createMany({ data: scenarios });
    console.log(`✅ ${scenarios.length} conversation scenarios seeded`);
  } else {
    console.log(
      `⏭️ Conversation scenarios already exist (${existingScenarios}), skipping`
    );
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
