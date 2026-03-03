import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { generateText } from 'ai';
import { getAIProvider } from '@harukoto/ai';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { REWARDS } from '@/lib/constants';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const rl = rateLimit(`chat:${user.id}`, RATE_LIMITS.AI);
    if (!rl.success) {
      return NextResponse.json(
        { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
        {
          status: 429,
          headers: {
            'Retry-After': String(
              Math.ceil((rl.reset - Date.now()) / 1000)
            ),
          },
        }
      );
    }

    const body = await request.json();
    const { transcript } = body as {
      transcript: { role: 'user' | 'assistant'; text: string }[];
      durationSeconds: number;
    };

    if (!transcript || !Array.isArray(transcript) || transcript.length === 0) {
      return NextResponse.json(
        { error: 'transcript is required' },
        { status: 400 }
      );
    }

    // Build conversation messages for DB storage
    const messages = transcript.map((entry) => ({
      role: entry.role,
      content: entry.text,
    }));

    // Generate feedback summary from AI
    let feedbackSummary: Record<string, unknown> | null = null;

    const conversationHistory = transcript.map((entry) => ({
      role: entry.role as 'user' | 'assistant',
      content: entry.text,
    }));

    if (conversationHistory.length > 1) {
      try {
        const { text } = await generateText({
          model: getAIProvider(),
          system: `あなたは日本語学習アプリの会話評価AIです。
ユーザーの会話を分析し、以下のJSON形式で評価を返してください:
{
  "overallScore": 1~100の総合点数,
  "fluency": 1~100の流暢さ,
  "accuracy": 1~100の正確さ,
  "vocabularyDiversity": 1~100の語彙多様性,
  "naturalness": 1~100の自然さ,
  "strengths": ["잘한 점1", "잘한 점2"],
  "improvements": ["개선할 점1", "개선할 점2"],
  "recommendedExpressions": ["추천 표현1", "추천 표현2"],
  "corrections": [
    {
      "original": "ユーザーが言った元の日本語（文法・語彙・助詞の間違いがある発話のみ）",
      "corrected": "正しい日本語表現",
      "explanation": "한국어로 왜 틀렸는지 간결하게 설명"
    }
  ]
}
corrections配列には、文法・語彙・助詞の誤りがあるユーザー発話のみを含めてください。誤りがない場合は空配列にしてください。`,
          messages: [
            ...conversationHistory,
            {
              role: 'user',
              content: '위 대화를 분석하여 평가를 JSON으로 반환해주세요.',
            },
          ],
        });

        const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
        feedbackSummary = JSON.parse(jsonMatch?.[1]?.trim() || text.trim());
      } catch {
        feedbackSummary = {
          overallScore: 0,
          fluency: 0,
          accuracy: 0,
          vocabularyDiversity: 0,
          naturalness: 0,
          strengths: [],
          improvements: ['대화가 너무 짧아 평가하기 어렵습니다.'],
          recommendedExpressions: [],
          corrections: [],
        };
      }
    }

    // Get a FREE scenario for the conversation record
    const freeScenario = await prisma.conversationScenario.findFirst({
      where: { category: 'FREE' },
    });

    // Create conversation record
    const now = new Date();

    const conversation = await prisma.conversation.create({
      data: {
        userId: user.id,
        scenarioId: freeScenario?.id,
        messages: JSON.parse(JSON.stringify(messages)),
        messageCount: messages.length,
        feedbackSummary: feedbackSummary
          ? JSON.parse(JSON.stringify(feedbackSummary))
          : undefined,
        endedAt: now,
      },
    });

    // Gamification (same pattern as chat/end/route.ts)
    const xpEarned = REWARDS.CONVERSATION_COMPLETE_XP;

    const { totalXp, newLevel, oldLevel, streak } = await prisma.$transaction(
      async (tx) => {
        const currentUser = await tx.user.findUniqueOrThrow({
          where: { id: user.id },
        });

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        await tx.dailyProgress.upsert({
          where: {
            userId_date: {
              userId: user.id,
              date: today,
            },
          },
          update: {
            conversationCount: { increment: 1 },
            xpEarned: { increment: xpEarned },
          },
          create: {
            userId: user.id,
            date: today,
            conversationCount: 1,
            xpEarned,
          },
        });

        const txTotalXp = currentUser.experiencePoints + xpEarned;
        const { level: txNewLevel } = calculateLevel(txTotalXp);
        const txOldLevel = currentUser.level;

        const txStreak = updateStreak(
          currentUser.lastStudyDate,
          currentUser.streakCount,
          currentUser.longestStreak
        );

        await tx.user.update({
          where: { id: user.id },
          data: {
            experiencePoints: txTotalXp,
            level: txNewLevel,
            streakCount: txStreak.streakCount,
            longestStreak: txStreak.longestStreak,
            lastStudyDate: new Date(),
          },
        });

        return {
          totalXp: txTotalXp,
          newLevel: txNewLevel,
          oldLevel: txOldLevel,
          streak: txStreak,
        };
      }
    );

    // Achievement checks
    const conversationCount = await prisma.conversation.count({
      where: { userId: user.id, endedAt: { not: null } },
    });

    const events: GameEvent[] = await checkAndGrantAchievements(user.id, {
      totalXp,
      newLevel,
      oldLevel,
      streakCount: streak.streakCount,
      conversationCount,
    });

    // Save events as notifications
    for (const event of events) {
      await prisma.notification.create({
        data: {
          userId: user.id,
          type: event.type,
          title: event.title,
          body: event.body,
          emoji: event.emoji,
        },
      });
    }

    return NextResponse.json({
      conversationId: conversation.id,
      feedbackSummary,
      xpEarned,
      events,
    });
  } catch (err) {
    console.error('Live feedback error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
