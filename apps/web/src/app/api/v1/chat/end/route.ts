import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { generateText } from 'ai';
import { getAIProvider } from '@harukoto/ai';

interface StoredMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { conversationId } = body;

    if (!conversationId) {
      return NextResponse.json(
        { error: 'conversationId is required' },
        { status: 400 }
      );
    }

    const conversation = await prisma.conversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) {
      return NextResponse.json(
        { error: 'Conversation not found' },
        { status: 404 }
      );
    }
    if (conversation.userId !== user.id) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }
    if (conversation.endedAt) {
      return NextResponse.json(
        { error: 'Conversation already ended' },
        { status: 400 }
      );
    }

    // Generate feedback summary from AI
    const storedMessages = conversation.messages as unknown as StoredMessage[];
    const conversationHistory = storedMessages
      .filter((m) => m.role !== 'system')
      .map((m) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      }));

    let feedbackSummary: Record<string, unknown> | null = null;

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
  "recommendedExpressions": ["추천 표현1", "추천 표현2"]
}`,
          messages: [
            ...conversationHistory,
            {
              role: 'user',
              content: '위 대화를 분석하여 평가를 JSON으로 반환해주세요.',
            },
          ],
        });

        const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/) || [
          null,
          text,
        ];
        feedbackSummary = JSON.parse(jsonMatch[1]!.trim());
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
        };
      }
    }

    // End the conversation
    const now = new Date();
    await prisma.conversation.update({
      where: { id: conversationId },
      data: {
        endedAt: now,
        feedbackSummary: feedbackSummary
          ? JSON.parse(JSON.stringify(feedbackSummary))
          : undefined,
      },
    });

    // Update daily progress
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    await prisma.dailyProgress.upsert({
      where: {
        userId_date: {
          userId: user.id,
          date: today,
        },
      },
      update: {
        conversationCount: { increment: 1 },
      },
      create: {
        userId: user.id,
        date: today,
        conversationCount: 1,
      },
    });

    return NextResponse.json({
      success: true,
      feedbackSummary,
    });
  } catch (err) {
    console.error('Chat end error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
