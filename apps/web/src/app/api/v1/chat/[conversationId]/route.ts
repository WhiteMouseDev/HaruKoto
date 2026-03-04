import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

interface StoredMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ conversationId: string }> }
) {
  try {
    const { conversationId } = await params;

    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const conversation = await prisma.conversation.findUnique({
      where: { id: conversationId },
      select: { userId: true },
    });
    if (!conversation) {
      return NextResponse.json(
        { error: '대화를 찾을 수 없습니다' },
        { status: 404 }
      );
    }
    if (conversation.userId !== user.id) {
      return NextResponse.json({ error: '권한이 없습니다' }, { status: 403 });
    }

    await prisma.conversation.delete({
      where: { id: conversationId },
    });

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error('Chat conversation DELETE error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ conversationId: string }> }
) {
  try {
    const { conversationId } = await params;

    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const conversation = await prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { scenario: true },
    });
    if (!conversation) {
      return NextResponse.json(
        { error: '대화를 찾을 수 없습니다' },
        { status: 404 }
      );
    }
    if (conversation.userId !== user.id) {
      return NextResponse.json({ error: '권한이 없습니다' }, { status: 403 });
    }

    const storedMessages = conversation.messages as unknown as StoredMessage[];

    // Extract AI/user messages (exclude system prompt)
    const messages = storedMessages
      .filter((m) => m.role !== 'system')
      .map((m, i) => {
        // Try to parse assistant messages as JSON (same format as chat/message response)
        if (m.role === 'assistant') {
          try {
            const jsonMatch = m.content.match(/```(?:json)?\s*([\s\S]*?)```/);
            const parsed = JSON.parse(jsonMatch?.[1]?.trim() || m.content.trim());
            return {
              id: `${m.role}-${i}`,
              role: 'ai' as const,
              messageJa: parsed.messageJa || m.content,
              messageKo: parsed.messageKo,
            };
          } catch {
            return {
              id: `${m.role}-${i}`,
              role: 'ai' as const,
              messageJa: m.content,
            };
          }
        }
        return {
          id: `${m.role}-${i}`,
          role: 'user' as const,
          messageJa: m.content,
        };
      });

    const scenario = conversation.scenario
      ? {
          title: conversation.scenario.title,
          titleJa: conversation.scenario.titleJa,
          difficulty: conversation.scenario.difficulty,
          situation: conversation.scenario.situation,
          yourRole: conversation.scenario.yourRole,
          aiRole: conversation.scenario.aiRole,
        }
      : null;

    return NextResponse.json({
      conversationId: conversation.id,
      messages,
      scenario,
      feedbackSummary: conversation.feedbackSummary,
      endedAt: conversation.endedAt,
    });
  } catch (err) {
    console.error('Chat conversation GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
