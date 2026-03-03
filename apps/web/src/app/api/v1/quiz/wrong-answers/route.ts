import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET(request: NextRequest) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const sessionId = request.nextUrl.searchParams.get('sessionId');
    if (!sessionId) {
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );
    }

    const session = await prisma.quizSession.findFirst({
      where: { id: sessionId, userId: user.id },
    });

    if (!session) {
      return NextResponse.json(
        { error: 'Session not found' },
        { status: 404 }
      );
    }

    const wrongAnswers = await prisma.quizAnswer.findMany({
      where: { sessionId, isCorrect: false },
      orderBy: { answeredAt: 'asc' },
    });

    if (wrongAnswers.length === 0) {
      return NextResponse.json({ wrongAnswers: [] });
    }

    const questionIds = wrongAnswers.map((a) => a.questionId);

    if (session.quizType === 'VOCABULARY') {
      const vocabs = await prisma.vocabulary.findMany({
        where: { id: { in: questionIds } },
      });
      const vocabMap = new Map(vocabs.map((v) => [v.id, v]));

      return NextResponse.json({
        wrongAnswers: wrongAnswers
          .map((a) => {
            const vocab = vocabMap.get(a.questionId);
            if (!vocab) return null;
            return {
              questionId: a.questionId,
              word: vocab.word,
              reading: vocab.reading,
              meaningKo: vocab.meaningKo,
              exampleSentence: vocab.exampleSentence,
              exampleTranslation: vocab.exampleTranslation,
            };
          })
          .filter(Boolean),
      });
    }

    if (session.quizType === 'GRAMMAR') {
      const grammars = await prisma.grammar.findMany({
        where: { id: { in: questionIds } },
      });
      const grammarMap = new Map(grammars.map((g) => [g.id, g]));

      return NextResponse.json({
        wrongAnswers: wrongAnswers
          .map((a) => {
            const grammar = grammarMap.get(a.questionId);
            if (!grammar) return null;
            return {
              questionId: a.questionId,
              word: grammar.pattern,
              reading: null,
              meaningKo: grammar.meaningKo,
              exampleSentence: null,
              exampleTranslation: grammar.explanation,
            };
          })
          .filter(Boolean),
      });
    }

    return NextResponse.json({ wrongAnswers: [] });
  } catch (err) {
    console.error('Wrong answers GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
