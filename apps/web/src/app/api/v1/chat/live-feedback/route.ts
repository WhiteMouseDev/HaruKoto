import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { generateObject } from 'ai';
import { z } from 'zod';
import { getAIProvider } from '@harukoto/ai';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { REWARDS } from '@/lib/constants';

const feedbackSchema = z.object({
  overallScore: z.number().min(0).max(100).describe('총합 점수 (0~100)'),
  fluency: z.number().min(0).max(100).describe('유창성 점수'),
  accuracy: z.number().min(0).max(100).describe('정확성 점수'),
  vocabularyDiversity: z.number().min(0).max(100).describe('어휘 다양성 점수'),
  naturalness: z.number().min(0).max(100).describe('자연스러움 점수'),
  strengths: z
    .array(z.string())
    .describe('잘한 점 목록 (한국어, 2~3개)'),
  improvements: z
    .array(z.string())
    .describe('개선할 점 목록 (한국어, 2~3개)'),
  recommendedExpressions: z
    .array(
      z.object({
        ja: z.string().describe('추천 일본어 표현'),
        ko: z.string().describe('한국어 뜻/설명'),
      })
    )
    .describe('추천 표현 목록 (일본어 + 한국어)'),
  corrections: z
    .array(
      z.object({
        original: z.string().describe('유저가 말한 원본 일본어'),
        corrected: z.string().describe('올바른 일본어 표현'),
        explanation: z.string().describe('한국어로 왜 틀렸는지 설명'),
      })
    )
    .describe('문법/어휘/조사 오류 교정 목록. 오류 없으면 빈 배열'),
  translatedTranscript: z
    .array(
      z.object({
        role: z.enum(['user', 'assistant']),
        ja: z.string().describe('원본 일본어 텍스트'),
        ko: z.string().describe('한국어 번역'),
      })
    )
    .describe('전체 대화 내역의 한국어 번역'),
});

export type FeedbackResult = z.infer<typeof feedbackSchema>;

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
    const { transcript, scenarioId, characterId } = body as {
      transcript: { role: 'user' | 'assistant'; text: string }[];
      durationSeconds: number;
      scenarioId?: string;
      characterId?: string;
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
    let feedbackSummary: FeedbackResult | null = null;

    const conversationHistory = transcript.map((entry) => ({
      role: entry.role as 'user' | 'assistant',
      content: entry.text,
    }));

    if (conversationHistory.length > 1) {
      try {
        const { object } = await generateObject({
          model: getAIProvider(),
          schema: feedbackSchema,
          system: `あなたは韓国人向け日本語学習アプリ「ハルコト」の会話評価AIです。
ユーザー（韓国人の日本語学習者）とAIチューターの会話を分析してください。

評価ルール:
- strengths, improvementsは韓国語で記述
- recommendedExpressionsは日本語表現(ja)と韓国語の意味(ko)の両方を提供
- correctionsはユーザー発話の文法・語彙・助詞の誤りのみ。誤りがない場合は空配列
- translatedTranscriptは全発話を日本語原文(ja)と韓国語翻訳(ko)の対で提供
- 翻訳は自然な韓国語で、直訳ではなく意訳を優先`,
          messages: [
            ...conversationHistory,
            {
              role: 'user',
              content: '위 대화를 분석하여 평가해주세요.',
            },
          ],
        });

        feedbackSummary = object;
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
          translatedTranscript: [],
        };
      }
    }

    // Resolve scenario: use provided scenarioId or fallback to FREE
    let resolvedScenarioId: string | undefined;
    if (scenarioId) {
      const scenario = await prisma.conversationScenario.findUnique({
        where: { id: scenarioId },
        select: { id: true },
      });
      resolvedScenarioId = scenario?.id;
    }
    if (!resolvedScenarioId) {
      const freeScenario = await prisma.conversationScenario.findFirst({
        where: { category: 'FREE' },
      });
      resolvedScenarioId = freeScenario?.id;
    }

    // Create conversation record
    const now = new Date();

    const conversation = await prisma.conversation.create({
      data: {
        userId: user.id,
        scenarioId: resolvedScenarioId,
        characterId: characterId || undefined,
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
