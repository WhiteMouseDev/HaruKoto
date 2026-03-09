import { PrismaClient } from '@prisma/client';
import { readFileSync, existsSync, readdirSync } from 'fs';
import { join } from 'path';

const prisma = new PrismaClient();

function loadJson<T>(relativePath: string): T {
  const fullPath = join(__dirname, '..', relativePath);
  return JSON.parse(readFileSync(fullPath, 'utf-8'));
}

function findJsonFiles(relativePath: string): string[] {
  const fullPath = join(__dirname, '..', relativePath);
  if (!existsSync(fullPath)) return [];
  return readdirSync(fullPath)
    .filter((f) => f.endsWith('.json'))
    .map((f) => `${relativePath}/${f}`);
}

// ─────────────────────────────────────────
// Vocabulary — upsert by (word, jlptLevel)
// ─────────────────────────────────────────
async function seedVocabulary() {
  const files = findJsonFiles('data/vocabulary');
  if (files.length === 0) return;

  let total = 0;
  let created = 0;

  for (const file of files) {
    const vocabData = loadJson<any[]>(file);
    total += vocabData.length;

    for (const v of vocabData) {
      try {
        await prisma.vocabulary.upsert({
          where: {
            word_reading_jlptLevel: { word: v.word, reading: v.reading, jlptLevel: v.jlptLevel },
          },
          update: {
            meaningKo: v.meaningKo,
            partOfSpeech: v.partOfSpeech,
            exampleSentence: v.exampleSentence,
            exampleReading: v.exampleReading,
            exampleTranslation: v.exampleTranslation,
            tags: v.tags,
            order: v.order,
          },
          create: {
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
          },
        });
        created++;
      } catch {
        // Duplicate — skip
      }
    }
  }

  const skipped = total - created;
  console.log(
    `✅ Vocabulary: ${created} created, ${skipped} already existed (${total} total)`
  );
}

// ─────────────────────────────────────────
// Grammar — upsert by (pattern, jlptLevel)
// ─────────────────────────────────────────
async function seedGrammar() {
  const files = findJsonFiles('data/grammar');
  if (files.length === 0) return;

  let total = 0;
  let created = 0;

  for (const file of files) {
    const grammarData = loadJson<any[]>(file);
    total += grammarData.length;

    for (const g of grammarData) {
      try {
        await prisma.grammar.upsert({
          where: {
            pattern_jlptLevel: { pattern: g.pattern, jlptLevel: g.jlptLevel },
          },
          update: {},
          create: {
            pattern: g.pattern,
            meaningKo: g.meaningKo,
            explanation: g.explanation,
            jlptLevel: g.jlptLevel,
            exampleSentences: g.exampleSentences,
            order: g.order,
          },
        });
        created++;
      } catch {
        // Duplicate — skip
      }
    }
  }

  const skipped = total - created;
  console.log(
    `✅ Grammar: ${created} created, ${skipped} already existed (${total} total)`
  );
}

// ─────────────────────────────────────────
// Conversation Scenarios — upsert by title
// ─────────────────────────────────────────
async function seedScenarios() {
  const file = 'data/scenarios/scenarios.json';
  const fullPath = join(__dirname, '..', file);
  if (!existsSync(fullPath)) {
    console.log('⏭️ Scenarios file not found, skipping');
    return;
  }

  const scenarios = loadJson<any[]>(file);
  let created = 0;

  for (const s of scenarios) {
    try {
      await prisma.conversationScenario.upsert({
        where: { title: s.title },
        update: {
          titleJa: s.titleJa,
          description: s.description,
          category: s.category,
          difficulty: s.difficulty,
          estimatedMinutes: s.estimatedMinutes,
          keyExpressions: s.keyExpressions,
          situation: s.situation,
          yourRole: s.yourRole,
          aiRole: s.aiRole,
          systemPrompt: s.systemPrompt,
          order: s.order,
        },
        create: s,
      });
      created++;
    } catch {
      // Skip
    }
  }

  console.log(`✅ Scenarios: ${created} upserted (${scenarios.length} total)`);
}

// ─────────────────────────────────────────
// AI Characters — upsert by name
// ─────────────────────────────────────────
async function seedCharacters() {
  const file = 'data/characters/ai-characters.json';
  const fullPath = join(__dirname, '..', file);
  if (!existsSync(fullPath)) {
    console.log('⏭️ AI characters file not found, skipping');
    return;
  }

  const existingCount = await prisma.aiCharacter.count();
  if (existingCount > 0) {
    console.log(
      `⏭️ AI characters already exist (${existingCount}), skipping`
    );
    return;
  }

  const characterData = loadJson<any[]>(file);
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
}

// ─────────────────────────────────────────
// Kana Characters — upsert by (kanaType, character)
// ─────────────────────────────────────────
async function seedKana() {
  const kanaFiles = [
    'data/kana/hiragana.json',
    'data/kana/katakana.json',
    'data/kana/hiragana-dakuten.json',
    'data/kana/katakana-dakuten.json',
    'data/kana/hiragana-youon.json',
    'data/kana/katakana-youon.json',
  ];

  let total = 0;
  let created = 0;

  for (const file of kanaFiles) {
    const fullPath = join(__dirname, '..', file);
    if (!existsSync(fullPath)) continue;

    const kanaData = loadJson<any[]>(file);
    total += kanaData.length;

    for (const k of kanaData) {
      try {
        await prisma.kanaCharacter.upsert({
          where: {
            kanaType_character: {
              kanaType: k.kanaType,
              character: k.character,
            },
          },
          update: {},
          create: {
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
          },
        });
        created++;
      } catch {
        // Skip
      }
    }
  }

  const skipped = total - created;
  console.log(
    `✅ Kana: ${created} created, ${skipped} already existed (${total} total)`
  );
}

// ─────────────────────────────────────────
// Kana Learning Stages — upsert by (kanaType, stageNumber)
// ─────────────────────────────────────────
async function seedKanaStages() {
  const stageFiles = [
    'data/kana/stages-hiragana.json',
    'data/kana/stages-katakana.json',
  ];

  let total = 0;
  let created = 0;

  for (const file of stageFiles) {
    const fullPath = join(__dirname, '..', file);
    if (!existsSync(fullPath)) continue;

    const stageData = loadJson<any[]>(file);
    total += stageData.length;

    for (const s of stageData) {
      try {
        await prisma.kanaLearningStage.upsert({
          where: {
            kanaType_stageNumber: {
              kanaType: s.kanaType,
              stageNumber: s.stageNumber,
            },
          },
          update: {},
          create: {
            kanaType: s.kanaType,
            stageNumber: s.stageNumber,
            title: s.title,
            description: s.description,
            characters: s.characters,
            order: s.order,
          },
        });
        created++;
      } catch {
        // Skip
      }
    }
  }

  const skipped = total - created;
  console.log(
    `✅ Kana Stages: ${created} created, ${skipped} already existed (${total} total)`
  );
}

// ─────────────────────────────────────────
// Cloze Questions — upsert by (sentence, jlptLevel)
// ─────────────────────────────────────────
async function seedCloze() {
  const files = findJsonFiles('data/cloze');
  if (files.length === 0) return;

  let total = 0;
  let created = 0;

  for (const file of files) {
    const clozeData = loadJson<any[]>(file);
    total += clozeData.length;

    for (const c of clozeData) {
      try {
        await prisma.clozeQuestion.upsert({
          where: {
            sentence_jlptLevel: {
              sentence: c.sentence,
              jlptLevel: c.jlptLevel,
            },
          },
          update: {},
          create: {
            sentence: c.sentence,
            translation: c.translation,
            correctAnswer: c.correctAnswer,
            options: c.options,
            explanation: c.explanation,
            grammarPoint: c.grammarPoint,
            jlptLevel: c.jlptLevel,
            difficulty: c.difficulty,
            order: c.order,
          },
        });
        created++;
      } catch {
        // Skip
      }
    }
  }

  const skipped = total - created;
  console.log(
    `✅ Cloze: ${created} created, ${skipped} already existed (${total} total)`
  );
}

// ─────────────────────────────────────────
// Sentence Arrange — upsert by (koreanSentence, jlptLevel)
// ─────────────────────────────────────────
async function seedSentenceArrange() {
  const files = findJsonFiles('data/sentence-arrange');
  if (files.length === 0) return;

  let total = 0;
  let created = 0;

  for (const file of files) {
    const arrangeData = loadJson<any[]>(file);
    total += arrangeData.length;

    for (const a of arrangeData) {
      try {
        await prisma.sentenceArrangeQuestion.upsert({
          where: {
            koreanSentence_jlptLevel: {
              koreanSentence: a.koreanSentence,
              jlptLevel: a.jlptLevel,
            },
          },
          update: {},
          create: {
            koreanSentence: a.koreanSentence,
            japaneseSentence: a.japaneseSentence,
            tokens: a.tokens,
            explanation: a.explanation,
            grammarPoint: a.grammarPoint,
            jlptLevel: a.jlptLevel,
            difficulty: a.difficulty,
            order: a.order,
          },
        });
        created++;
      } catch {
        // Skip
      }
    }
  }

  const skipped = total - created;
  console.log(
    `✅ Sentence Arrange: ${created} created, ${skipped} already existed (${total} total)`
  );
}

// ─────────────────────────────────────────
// Main
// ─────────────────────────────────────────
async function main() {
  console.log('🌸 Seeding HaruKoto database...\n');

  await seedVocabulary();
  await seedGrammar();
  await seedScenarios();
  await seedCloze();
  await seedSentenceArrange();
  await seedKana();
  await seedKanaStages();
  await seedCharacters();

  console.log('\n🌸 Seeding complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
