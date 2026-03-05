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

  // 1. Seed Vocabulary (N5 + N4)
  const vocabFiles = [
    { file: 'data/vocabulary/n5-words.json', level: 'N5' },
    { file: 'data/vocabulary/n4-words.json', level: 'N4' },
  ];

  for (const { file, level } of vocabFiles) {
    const existingCount = await prisma.vocabulary.count({
      where: { jlptLevel: level as any },
    });
    if (existingCount === 0) {
      try {
        const vocabData = loadJson<any[]>(file);
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
        console.log(`✅ ${vocabData.length} ${level} vocabulary words seeded`);
      } catch (e) {
        console.log(`⏭️ ${level} vocabulary file not found, skipping`);
      }
    } else {
      console.log(`⏭️ ${level} vocabulary already exists (${existingCount}), skipping`);
    }
  }

  // 2. Seed Grammar (N5 + N4)
  const grammarFiles = [
    { file: 'data/grammar/n5-grammar.json', level: 'N5' },
    { file: 'data/grammar/n4-grammar.json', level: 'N4' },
  ];

  for (const { file, level } of grammarFiles) {
    const existingCount = await prisma.grammar.count({
      where: { jlptLevel: level as any },
    });
    if (existingCount === 0) {
      try {
        const grammarData = loadJson<any[]>(file);
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
        console.log(`✅ ${grammarData.length} ${level} grammar patterns seeded`);
      } catch (e) {
        console.log(`⏭️ ${level} grammar file not found, skipping`);
      }
    } else {
      console.log(`⏭️ ${level} grammar already exists (${existingCount}), skipping`);
    }
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

  // 4. Seed AI Characters (Voice Call)
  const existingCharacters = await prisma.aiCharacter.count();
  if (existingCharacters === 0) {
    try {
      const characterData = loadJson<any[]>('data/characters/ai-characters.json');
      await prisma.aiCharacter.createMany({
        data: characterData.map((c) => ({
          name: c.name,
          nameJa: c.nameJa,
          nameRomaji: c.nameRomaji,
          gender: c.gender,
          ageDescription: c.ageDescription,
          description: c.description,
          relationship: c.relationship,
          backgroundStory: c.backgroundStory,
          personality: c.personality,
          voiceName: c.voiceName,
          voiceBackup: c.voiceBackup,
          speechStyle: c.speechStyle,
          targetLevel: c.targetLevel,
          silenceMs: c.silenceMs,
          tier: c.tier,
          unlockCondition: c.unlockCondition,
          isDefault: c.isDefault,
          avatarEmoji: c.avatarEmoji,
          avatarUrl: c.avatarUrl,
          gradient: c.gradient,
          order: c.order,
        })),
      });
      console.log(`✅ ${characterData.length} AI characters seeded`);
    } catch (e) {
      console.log(`⏭️ AI characters file not found, skipping`);
    }
  } else {
    console.log(`⏭️ AI characters already exist (${existingCharacters}), skipping`);
  }

  // 5. Seed Kana Characters (Hiragana + Katakana)
  const kanaFiles = [
    { file: 'data/kana/hiragana.json', type: 'HIRAGANA' },
    { file: 'data/kana/katakana.json', type: 'KATAKANA' },
  ];

  for (const { file, type } of kanaFiles) {
    const existingCount = await prisma.kanaCharacter.count({
      where: { kanaType: type as any },
    });
    if (existingCount === 0) {
      try {
        const kanaData = loadJson<any[]>(file);
        await prisma.kanaCharacter.createMany({
          data: kanaData.map((k) => ({
            kanaType: k.kanaType,
            character: k.character,
            romaji: k.romaji,
            pronunciation: k.pronunciation,
            row: k.row,
            column: k.column,
            strokeCount: k.strokeCount,
            category: k.category,
            exampleWord: k.exampleWord,
            exampleReading: k.exampleReading,
            exampleMeaning: k.exampleMeaning,
            order: k.order,
          })),
        });
        console.log(`✅ ${kanaData.length} ${type} characters seeded`);
      } catch (e) {
        console.log(`⏭️ ${type} kana file not found, skipping`);
      }
    } else {
      console.log(`⏭️ ${type} kana already exists (${existingCount}), skipping`);
    }
  }

  // 4b. Seed Kana Dakuten + Handakuten Characters
  const dakutenFiles = [
    { file: 'data/kana/hiragana-dakuten.json', type: 'HIRAGANA' },
    { file: 'data/kana/katakana-dakuten.json', type: 'KATAKANA' },
  ];

  for (const { file, type } of dakutenFiles) {
    const existingDakuten = await prisma.kanaCharacter.count({
      where: { kanaType: type as any, category: 'dakuten' },
    });
    const existingHandakuten = await prisma.kanaCharacter.count({
      where: { kanaType: type as any, category: 'handakuten' },
    });
    if (existingDakuten === 0 && existingHandakuten === 0) {
      try {
        const kanaData = loadJson<any[]>(file);
        await prisma.kanaCharacter.createMany({
          data: kanaData.map((k) => ({
            kanaType: k.kanaType,
            character: k.character,
            romaji: k.romaji,
            pronunciation: k.pronunciation,
            row: k.row,
            column: k.column,
            strokeCount: k.strokeCount,
            category: k.category,
            exampleWord: k.exampleWord,
            exampleReading: k.exampleReading,
            exampleMeaning: k.exampleMeaning,
            order: k.order,
          })),
        });
        console.log(`✅ ${kanaData.length} ${type} dakuten/handakuten characters seeded`);
      } catch (e) {
        console.log(`⏭️ ${type} dakuten file not found, skipping`);
      }
    } else {
      console.log(
        `⏭️ ${type} dakuten/handakuten already exists (${existingDakuten + existingHandakuten}), skipping`
      );
    }
  }

  // 4c. Seed Kana Youon (Compound Kana) Characters
  const youonFiles = [
    { file: 'data/kana/hiragana-youon.json', type: 'HIRAGANA' },
    { file: 'data/kana/katakana-youon.json', type: 'KATAKANA' },
  ];

  for (const { file, type } of youonFiles) {
    const existingYouon = await prisma.kanaCharacter.count({
      where: { kanaType: type as any, category: { startsWith: 'youon' } },
    });
    if (existingYouon === 0) {
      try {
        const kanaData = loadJson<any[]>(file);
        await prisma.kanaCharacter.createMany({
          data: kanaData.map((k) => ({
            kanaType: k.kanaType,
            character: k.character,
            romaji: k.romaji,
            pronunciation: k.pronunciation,
            row: k.row,
            column: k.column,
            strokeCount: k.strokeCount,
            category: k.category,
            exampleWord: k.exampleWord,
            exampleReading: k.exampleReading,
            exampleMeaning: k.exampleMeaning,
            order: k.order,
          })),
        });
        console.log(`✅ ${kanaData.length} ${type} youon characters seeded`);
      } catch (e) {
        console.log(`⏭️ ${type} youon file not found, skipping`);
      }
    } else {
      console.log(`⏭️ ${type} youon already exists (${existingYouon}), skipping`);
    }
  }

  // 5. Seed Kana Learning Stages
  const stageFiles = [
    { file: 'data/kana/stages-hiragana.json', type: 'HIRAGANA' },
    { file: 'data/kana/stages-katakana.json', type: 'KATAKANA' },
  ];

  for (const { file, type } of stageFiles) {
    const existingCount = await prisma.kanaLearningStage.count({
      where: { kanaType: type as any },
    });
    if (existingCount === 0) {
      try {
        const stageData = loadJson<any[]>(file);
        await prisma.kanaLearningStage.createMany({
          data: stageData.map((s) => ({
            kanaType: s.kanaType,
            stageNumber: s.stageNumber,
            title: s.title,
            description: s.description,
            characters: s.characters,
            order: s.order,
          })),
        });
        console.log(`✅ ${stageData.length} ${type} stages seeded`);
      } catch (e) {
        console.log(`⏭️ ${type} stages file not found, skipping`);
      }
    } else {
      // Check if new stages need to be added (e.g. youon stages 11-12)
      try {
        const stageData = loadJson<any[]>(file);
        for (const s of stageData) {
          const exists = await prisma.kanaLearningStage.findUnique({
            where: { kanaType_stageNumber: { kanaType: s.kanaType, stageNumber: s.stageNumber } },
          });
          if (!exists) {
            await prisma.kanaLearningStage.create({
              data: {
                kanaType: s.kanaType,
                stageNumber: s.stageNumber,
                title: s.title,
                description: s.description,
                characters: s.characters,
                order: s.order,
              },
            });
            console.log(`✅ ${type} Stage ${s.stageNumber} (${s.title}) seeded`);
          }
        }
      } catch (e) {
        // Ignore
      }
      console.log(`⏭️ ${type} stages already exist (${existingCount}), checked for new stages`);
    }
  }

  // 9. Seed Cloze Questions (N5)
  const clozeFiles = [
    { file: 'data/cloze/n5-cloze.json', level: 'N5' },
  ];

  for (const { file, level } of clozeFiles) {
    const existingCount = await prisma.clozeQuestion.count({
      where: { jlptLevel: level as any },
    });
    if (existingCount === 0) {
      try {
        const clozeData = loadJson<any[]>(file);
        await prisma.clozeQuestion.createMany({
          data: clozeData.map((c) => ({
            sentence: c.sentence,
            translation: c.translation,
            correctAnswer: c.correctAnswer,
            options: c.options,
            explanation: c.explanation,
            grammarPoint: c.grammarPoint,
            jlptLevel: c.jlptLevel,
            difficulty: c.difficulty,
            order: c.order,
          })),
        });
        console.log(`✅ ${clozeData.length} ${level} cloze questions seeded`);
      } catch (e) {
        console.log(`⏭️ ${level} cloze file not found, skipping`);
      }
    } else {
      console.log(`⏭️ ${level} cloze questions already exist (${existingCount}), skipping`);
    }
  }

  // 10. Seed Sentence Arrange Questions (N5)
  const arrangeFiles = [
    { file: 'data/sentence-arrange/n5-arrange.json', level: 'N5' },
  ];

  for (const { file, level } of arrangeFiles) {
    const existingCount = await prisma.sentenceArrangeQuestion.count({
      where: { jlptLevel: level as any },
    });
    if (existingCount === 0) {
      try {
        const arrangeData = loadJson<any[]>(file);
        await prisma.sentenceArrangeQuestion.createMany({
          data: arrangeData.map((a) => ({
            koreanSentence: a.koreanSentence,
            japaneseSentence: a.japaneseSentence,
            tokens: a.tokens,
            explanation: a.explanation,
            grammarPoint: a.grammarPoint,
            jlptLevel: a.jlptLevel,
            difficulty: a.difficulty,
            order: a.order,
          })),
        });
        console.log(`✅ ${arrangeData.length} ${level} sentence arrange questions seeded`);
      } catch (e) {
        console.log(`⏭️ ${level} sentence arrange file not found, skipping`);
      }
    } else {
      console.log(`⏭️ ${level} sentence arrange questions already exist (${existingCount}), skipping`);
    }
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
