import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { REWARDS, QUIZ_CONFIG } from '@/lib/constants';
import { getTodayKST } from '@/lib/date';
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
        const today = getTodayKST();

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
      // Cloze-specific fields
      sentence?: string;
      translation?: string;
      explanation?: string;
      grammarPoint?: string;
    };
    let questions: Question[] = [];

    if (mode === 'arrange') {
      // Sentence arrange mode: fetch SentenceArrangeQuestion records
      const arrangeQuestions = await prisma.sentenceArrangeQuestion.findMany({
        where: { jlptLevel },
        orderBy: { order: 'asc' },
      });

      const selected = shuffleArray(arrangeQuestions).slice(0, count);

      if (selected.length === 0) {
        return NextResponse.json({
          questions: [],
          sessionId: null,
          message: '어순 배열 문제가 없습니다',
        });
      }

      const arrangeQuestionsData = selected.map((aq) => ({
        questionId: aq.id,
        koreanSentence: aq.koreanSentence,
        japaneseSentence: aq.japaneseSentence,
        tokens: aq.tokens,
        explanation: aq.explanation,
        grammarPoint: aq.grammarPoint ?? undefined,
        // Compatibility fields for session tracking
        questionText: aq.koreanSentence,
        questionSubText: null,
        hint: null,
        options: [],
        correctOptionId: aq.id,
      }));

      const session = await prisma.quizSession.create({
        data: {
          userId: user.id,
          quizType: 'SENTENCE_ARRANGE',
          jlptLevel,
          totalQuestions: arrangeQuestionsData.length,
          questionsData: JSON.parse(JSON.stringify(arrangeQuestionsData)),
        },
      });

      return NextResponse.json({
        sessionId: session.id,
        questions: arrangeQuestionsData,
        totalQuestions: arrangeQuestionsData.length,
      });
    }

    if (mode === 'typing') {
      // Typing mode: generate character bank questions from vocabulary
      const HIRAGANA_POOL = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ';
      const KATAKANA_POOL = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ';

      const words = await prisma.vocabulary.findMany({
        where: { jlptLevel },
        orderBy: { order: 'asc' },
      });

      const selected = shuffleArray(words).slice(0, count);

      if (selected.length === 0) {
        return NextResponse.json({
          questions: [],
          sessionId: null,
          message: '단어 쓰기 문제가 없습니다',
        });
      }

      const typingQuestionsData = selected.map((word) => {
        const answer = word.reading || word.word;
        const answerChars = [...answer];

        // Determine if answer is hiragana or katakana
        const isKatakana = answerChars.some((c) => KATAKANA_POOL.includes(c));
        const pool = isKatakana ? KATAKANA_POOL : HIRAGANA_POOL;

        // Generate 2-3 distractor characters not in the answer
        const distractorCount = Math.min(3, Math.max(2, Math.ceil(answerChars.length * 0.6)));
        const poolChars = [...pool].filter((c) => !answerChars.includes(c));
        const distractors = shuffleArray(poolChars).slice(0, distractorCount);

        return {
          questionId: word.id,
          prompt: word.meaningKo,
          answer,
          hint: word.word !== answer ? word.word : null,
          distractors,
          // Compatibility fields
          questionText: word.meaningKo,
          questionSubText: null,
          options: [],
          correctOptionId: word.id,
        };
      });

      const session = await prisma.quizSession.create({
        data: {
          userId: user.id,
          quizType: 'VOCABULARY',
          jlptLevel,
          totalQuestions: typingQuestionsData.length,
          questionsData: JSON.parse(JSON.stringify(typingQuestionsData)),
        },
      });

      return NextResponse.json({
        sessionId: session.id,
        questions: typingQuestionsData,
        totalQuestions: typingQuestionsData.length,
      });
    }

    if (mode === 'cloze') {
      // Cloze mode: fetch ClozeQuestion records
      const clozeQuestions = await prisma.clozeQuestion.findMany({
        where: { jlptLevel },
        orderBy: { order: 'asc' },
      });

      const selected = shuffleArray(clozeQuestions).slice(0, count);

      if (selected.length === 0) {
        return NextResponse.json({
          questions: [],
          sessionId: null,
          message: '빈칸 채우기 문제가 없습니다',
        });
      }

      questions = selected.map((cq) => {
        const options = (cq.options as string[]).map((opt, i) => ({
          id: `${cq.id}_opt_${i}`,
          text: opt,
        }));
        const correctOption = options.find((o) => o.text === cq.correctAnswer);

        return {
          questionId: cq.id,
          questionText: cq.sentence,
          questionSubText: null,
          hint: null,
          options: shuffleArray(options),
          correctOptionId: correctOption?.id || options[0].id,
          sentence: cq.sentence,
          translation: cq.translation,
          explanation: cq.explanation,
          grammarPoint: cq.grammarPoint ?? undefined,
        };
      });

      const session = await prisma.quizSession.create({
        data: {
          userId: user.id,
          quizType: 'CLOZE',
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
    } else if (mode === 'review') {
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

    // Handle empty content for levels without data
    if (questions.length === 0) {
      return NextResponse.json({
        questions: [],
        sessionId: null,
        message: '이 레벨의 콘텐츠를 준비하고 있어요',
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
