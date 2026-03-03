import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

type FeedbackJson = {
  overallScore?: number;
};

export async function GET(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const cursor = searchParams.get('cursor');
    const limit = Math.min(Number(searchParams.get('limit')) || 10, 30);

    const conversations = await prisma.conversation.findMany({
      where: {
        userId: user.id,
        endedAt: { not: null },
      },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      select: {
        id: true,
        createdAt: true,
        endedAt: true,
        messageCount: true,
        feedbackSummary: true,
        scenario: {
          select: {
            title: true,
            titleJa: true,
            category: true,
            difficulty: true,
          },
        },
      },
    });

    const hasMore = conversations.length > limit;
    const items = hasMore ? conversations.slice(0, limit) : conversations;
    const nextCursor = hasMore ? items[items.length - 1].id : null;

    const history = items.map((c) => {
      const fb = c.feedbackSummary as FeedbackJson | null;
      return {
        id: c.id,
        createdAt: c.createdAt,
        endedAt: c.endedAt,
        messageCount: c.messageCount,
        overallScore: fb?.overallScore ?? null,
        scenario: c.scenario
          ? {
              title: c.scenario.title,
              titleJa: c.scenario.titleJa,
              category: c.scenario.category,
              difficulty: c.scenario.difficulty,
            }
          : null,
      };
    });

    return NextResponse.json({ history, nextCursor });
  } catch (err) {
    console.error('Chat history error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
