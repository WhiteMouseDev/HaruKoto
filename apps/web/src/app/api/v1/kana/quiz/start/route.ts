import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { shuffleArray } from '@/lib/shuffle';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const body = await request.json();
    const {
      kanaType,
      stageNumber,
      quizMode = 'recognition',
      count = 5,
    } = body;

    if (!kanaType || (kanaType !== 'HIRAGANA' && kanaType !== 'KATAKANA')) {
      return NextResponse.json(
        { error: 'kanaType must be HIRAGANA or KATAKANA' },
        { status: 400 }
      );
    }

    // Get target characters based on stage or all learned
    let targetCharacters;

    if (stageNumber) {
      // Stage-specific: get characters from this stage
      const stage = await prisma.kanaLearningStage.findUnique({
        where: { kanaType_stageNumber: { kanaType, stageNumber } },
      });
      if (!stage) {
        return NextResponse.json(
          { error: 'Stage not found' },
          { status: 404 }
        );
      }

      targetCharacters = await prisma.kanaCharacter.findMany({
        where: {
          kanaType,
          character: { in: stage.characters },
        },
        orderBy: { order: 'asc' },
      });

      // Also include characters from previous stages for cumulative review
      if (stageNumber > 3) {
        const prevStages = await prisma.kanaLearningStage.findMany({
          where: {
            kanaType,
            stageNumber: { gte: Math.max(1, stageNumber - 2), lt: stageNumber },
          },
        });
        const prevChars = prevStages.flatMap((s) => s.characters);
        const additionalChars = await prisma.kanaCharacter.findMany({
          where: {
            kanaType,
            character: { in: prevChars },
            id: { notIn: targetCharacters.map((c) => c.id) },
          },
        });
        targetCharacters = [...targetCharacters, ...additionalChars];
      }
    } else {
      // All learned characters (have UserKanaProgress)
      targetCharacters = await prisma.kanaCharacter.findMany({
        where: {
          kanaType,
          userProgress: { some: { userId: user.id } },
        },
      });

      // Fallback: if no progress yet, use first stage
      if (targetCharacters.length === 0) {
        const firstStage = await prisma.kanaLearningStage.findUnique({
          where: { kanaType_stageNumber: { kanaType, stageNumber: 1 } },
        });
        if (firstStage) {
          targetCharacters = await prisma.kanaCharacter.findMany({
            where: {
              kanaType,
              character: { in: firstStage.characters },
            },
          });
        }
      }
    }

    if (!targetCharacters || targetCharacters.length === 0) {
      return NextResponse.json({
        questions: [],
        sessionId: null,
        message: '출제할 문자가 없습니다',
      });
    }

    type Question = {
      questionId: string;
      questionText: string;
      questionSubText: string | null;
      options: { id: string; text: string }[];
      correctOptionId: string;
    };

    let questions: Question[];

    if (quizMode === 'kana_matching') {
      // Hiragana ↔ Katakana matching mode (direction depends on kanaType)
      const isHiraganaToKatakana = kanaType === 'HIRAGANA';

      const questionType = isHiraganaToKatakana ? 'HIRAGANA' : 'KATAKANA';
      const answerType = isHiraganaToKatakana ? 'KATAKANA' : 'HIRAGANA';
      const subText = isHiraganaToKatakana ? '→ 가타카나는?' : '→ 히라가나는?';

      const [questionChars, answerChars] = await Promise.all([
        prisma.kanaCharacter.findMany({
          where: { kanaType: questionType },
        }),
        prisma.kanaCharacter.findMany({
          where: { kanaType: answerType },
        }),
      ]);

      const answerByRomaji = new Map(
        answerChars.map((c) => [c.romaji, c])
      );

      const matchable = questionChars.filter((q) =>
        answerByRomaji.has(q.romaji)
      );

      // Prefer learned characters if available
      const learnedIds = new Set(
        targetCharacters
          .filter((c) => c.kanaType === questionType)
          .map((c) => c.id)
      );

      const candidates =
        learnedIds.size > 0
          ? matchable.filter((q) => learnedIds.has(q.id))
          : matchable;

      const sourceChars =
        candidates.length >= count ? candidates : matchable;

      const selected = shuffleArray(sourceChars).slice(0, count);

      questions = selected.map((qChar) => {
        const correctAnswer = answerByRomaji.get(qChar.romaji)!;
        const wrongAnswers = shuffleArray(
          answerChars.filter((c) => c.romaji !== qChar.romaji)
        ).slice(0, 3);

        const options = shuffleArray([
          { id: correctAnswer.id, text: correctAnswer.character },
          ...wrongAnswers.map((c) => ({ id: c.id, text: c.character })),
        ]);

        return {
          questionId: qChar.id,
          questionText: qChar.character,
          questionSubText: subText,
          options,
          correctOptionId: correctAnswer.id,
        };
      });
    } else {
      // recognition / sound_matching modes
      // Get all characters of same type for wrong options pool
      const allCharacters = await prisma.kanaCharacter.findMany({
        where: { kanaType },
      });

      // Select quiz questions (shuffle + take count)
      const selectedChars = shuffleArray(targetCharacters).slice(0, count);

      questions = selectedChars.map((char) => {
        if (quizMode === 'recognition') {
          // Show kana → pick romaji
          const wrongOptions = shuffleArray(
            allCharacters.filter((c) => c.id !== char.id)
          ).slice(0, 3);

          const options = shuffleArray([
            { id: char.id, text: char.romaji },
            ...wrongOptions.map((w) => ({ id: w.id, text: w.romaji })),
          ]);

          return {
            questionId: char.id,
            questionText: char.character,
            questionSubText: null,
            options,
            correctOptionId: char.id,
          };
        } else {
          // sound_matching: Show romaji → pick kana
          const wrongOptions = shuffleArray(
            allCharacters.filter((c) => c.id !== char.id)
          ).slice(0, 3);

          const options = shuffleArray([
            { id: char.id, text: char.character },
            ...wrongOptions.map((w) => ({ id: w.id, text: w.character })),
          ]);

          return {
            questionId: char.id,
            questionText: char.romaji,
            questionSubText: char.pronunciation,
            options,
            correctOptionId: char.id,
          };
        }
      });
    }

    // Create quiz session (reuse QuizSession with KANA type)
    const session = await prisma.quizSession.create({
      data: {
        userId: user.id,
        quizType: 'KANA',
        jlptLevel: 'N5',
        totalQuestions: questions.length,
        questionsData: JSON.parse(JSON.stringify(questions)),
      },
    });

    return NextResponse.json({
      sessionId: session.id,
      questions,
      totalQuestions: questions.length,
    });
  } catch (err) {
    console.error('Kana quiz start error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
