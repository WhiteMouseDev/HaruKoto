import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { REWARDS, QUIZ_CONFIG } from '@/lib/constants';
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
    const { quizType, jlptLevel, count = QUIZ_CONFIG.DEFAULT_COUNT, mode = 'normal' } = body;

    if (!quizType || !jlptLevel) {
      return NextResponse.json(
        { error: 'quizType and jlptLevel are required' },
        { status: 400 }
      );
    }

    // Auto-complete any incomplete sessions
    const incompleteSessions = await prisma.quizSession.findMany({
      where: { userId: user.id, completedAt: null },
      include: { answers: true },
    });

    for (const oldSession of incompleteSessions) {
      const correctCount = oldSession.answers.filter(a => a.isCorrect).length;
      await prisma.quizSession.update({
        where: { id: oldSession.id },
        data: {
          completedAt: new Date(),
          correctCount,
        },
      });

      // Award partial XP
      if (correctCount > 0) {
        const partialXp = correctCount * REWARDS.QUIZ_XP_PER_CORRECT;
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        await prisma.dailyProgress.upsert({
          where: { userId_date: { userId: user.id, date: today } },
          update: {
            xpEarned: { increment: partialXp },
            correctAnswers: { increment: correctCount },
            totalAnswers: { increment: oldSession.answers.length },
          },
          create: {
            userId: user.id,
            date: today,
            xpEarned: partialXp,
            correctAnswers: correctCount,
            totalAnswers: oldSession.answers.length,
          },
        });

        await prisma.user.update({
          where: { id: user.id },
          data: { experiencePoints: { increment: partialXp } },
        });
      }
    }

    // Fetch words that need review first, then new words
    type Question = {
      questionId: string;
      questionText: string;
      questionSubText: string | null;
      hint: string | null;
      options: { id: string; text: string }[];
      correctOptionId: string;
    };
    let questions: Question[] = [];

    if (mode === 'review') {
      // Review mode: focus on previously incorrect items
      if (quizType === 'VOCABULARY') {
        const incorrectProgress = await prisma.userVocabProgress.findMany({
          where: {
            userId: user.id,
            incorrectCount: { gt: 0 },
            mastered: false,
            vocabulary: { jlptLevel },
          },
          include: { vocabulary: true },
          orderBy: { incorrectCount: 'desc' },
          take: count,
        });

        let reviewItems = incorrectProgress.map((p) => p.vocabulary);

        // Supplement with due-for-review items if not enough
        if (reviewItems.length < count) {
          const existingIds = reviewItems.map((v) => v.id);
          const dueItems = await prisma.userVocabProgress.findMany({
            where: {
              userId: user.id,
              mastered: false,
              nextReviewAt: { lte: new Date() },
              vocabularyId: { notIn: existingIds },
              vocabulary: { jlptLevel },
            },
            include: { vocabulary: true },
            orderBy: { nextReviewAt: 'asc' },
            take: count - reviewItems.length,
          });
          reviewItems = [...reviewItems, ...dueItems.map((p) => p.vocabulary)];
        }

        if (reviewItems.length === 0) {
          return NextResponse.json({
            questions: [],
            sessionId: null,
            message: '복습할 문제가 없습니다',
          });
        }

        const allVocab = await prisma.vocabulary.findMany({
          where: { jlptLevel },
          select: { id: true, meaningKo: true },
        });

        questions = reviewItems.map((word) => {
          const wrongOptions = shuffleArray(
            allVocab.filter((v) => v.id !== word.id)
          ).slice(0, QUIZ_CONFIG.WRONG_OPTIONS_COUNT);

          const options = shuffleArray([
            { id: word.id, text: word.meaningKo },
            ...wrongOptions.map((w) => ({ id: w.id, text: w.meaningKo })),
          ]);

          return {
            questionId: word.id,
            questionText: word.word,
            questionSubText: word.reading,
            hint: word.exampleSentence,
            options,
            correctOptionId: word.id,
          };
        });
      } else if (quizType === 'GRAMMAR') {
        const incorrectProgress = await prisma.userGrammarProgress.findMany({
          where: {
            userId: user.id,
            incorrectCount: { gt: 0 },
            mastered: false,
            grammar: { jlptLevel },
          },
          include: { grammar: true },
          orderBy: { incorrectCount: 'desc' },
          take: count,
        });

        let reviewItems = incorrectProgress.map((p) => p.grammar);

        if (reviewItems.length < count) {
          const existingIds = reviewItems.map((g) => g.id);
          const dueItems = await prisma.userGrammarProgress.findMany({
            where: {
              userId: user.id,
              mastered: false,
              nextReviewAt: { lte: new Date() },
              grammarId: { notIn: existingIds },
              grammar: { jlptLevel },
            },
            include: { grammar: true },
            orderBy: { nextReviewAt: 'asc' },
            take: count - reviewItems.length,
          });
          reviewItems = [...reviewItems, ...dueItems.map((p) => p.grammar)];
        }

        if (reviewItems.length === 0) {
          return NextResponse.json({
            questions: [],
            sessionId: null,
            message: '복습할 문제가 없습니다',
          });
        }

        const allGrammar = await prisma.grammar.findMany({
          where: { jlptLevel },
          select: { id: true, meaningKo: true },
        });

        questions = reviewItems.map((grammar) => {
          const wrongOptions = shuffleArray(
            allGrammar.filter((g) => g.id !== grammar.id)
          ).slice(0, QUIZ_CONFIG.WRONG_OPTIONS_COUNT);

          const options = shuffleArray([
            { id: grammar.id, text: grammar.meaningKo },
            ...wrongOptions.map((g) => ({ id: g.id, text: g.meaningKo })),
          ]);

          return {
            questionId: grammar.id,
            questionText: grammar.pattern,
            questionSubText: null,
            hint: grammar.explanation,
            options,
            correctOptionId: grammar.id,
          };
        });
      }
    } else if (quizType === 'VOCABULARY') {
      // 1. Get words due for review (spaced repetition)
      const reviewWords = await prisma.vocabulary.findMany({
        where: {
          jlptLevel,
          userProgress: {
            some: {
              userId: user.id,
              mastered: false,
              nextReviewAt: { lte: new Date() },
            },
          },
        },
        take: Math.ceil(count * QUIZ_CONFIG.REVIEW_RATIO),
        orderBy: { userProgress: { _count: 'asc' } },
      });

      // 2. Get new words (not yet studied)
      const remaining = count - reviewWords.length;
      const newWords = await prisma.vocabulary.findMany({
        where: {
          jlptLevel,
          userProgress: { none: { userId: user.id } },
        },
        take: remaining,
        orderBy: { order: 'asc' },
      });

      // 3. If still not enough, get random words
      const allSelected = [...reviewWords, ...newWords];
      if (allSelected.length < count) {
        const existingIds = allSelected.map((w) => w.id);
        const extraWords = await prisma.vocabulary.findMany({
          where: {
            jlptLevel,
            id: { notIn: existingIds },
          },
          take: count - allSelected.length,
        });
        allSelected.push(...extraWords);
      }

      // Generate 4-choice questions
      const allVocab = await prisma.vocabulary.findMany({
        where: { jlptLevel },
        select: { id: true, meaningKo: true },
      });

      questions = allSelected.map((word) => {
        // Pick 3 wrong answers from same level
        const wrongOptions = shuffleArray(
          allVocab.filter((v) => v.id !== word.id)
        ).slice(0, QUIZ_CONFIG.WRONG_OPTIONS_COUNT);

        const options = shuffleArray([
          { id: word.id, text: word.meaningKo },
          ...wrongOptions.map((w) => ({ id: w.id, text: w.meaningKo })),
        ]);

        return {
          questionId: word.id,
          questionText: word.word,
          questionSubText: word.reading,
          hint: word.exampleSentence,
          options,
          correctOptionId: word.id,
        };
      });
    } else if (quizType === 'GRAMMAR') {
      const grammars = await prisma.grammar.findMany({
        where: { jlptLevel },
        take: count,
        orderBy: { order: 'asc' },
      });

      const allGrammar = await prisma.grammar.findMany({
        where: { jlptLevel },
        select: { id: true, meaningKo: true },
      });

      questions = grammars.map((grammar) => {
        const wrongOptions = shuffleArray(
          allGrammar.filter((g) => g.id !== grammar.id)
        ).slice(0, QUIZ_CONFIG.WRONG_OPTIONS_COUNT);

        const options = shuffleArray([
          { id: grammar.id, text: grammar.meaningKo },
          ...wrongOptions.map((g) => ({ id: g.id, text: g.meaningKo })),
        ]);

        return {
          questionId: grammar.id,
          questionText: grammar.pattern,
          questionSubText: null,
          hint: grammar.explanation,
          options,
          correctOptionId: grammar.id,
        };
      });
    }

    // Create quiz session
    const session = await prisma.quizSession.create({
      data: {
        userId: user.id,
        quizType,
        jlptLevel,
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
    console.error('Quiz start error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
