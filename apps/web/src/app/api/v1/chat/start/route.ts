import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { generateText } from 'ai';
import { getAIProvider, SYSTEM_PROMPTS } from '@harukoto/ai';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';
import { checkAiLimit } from '@/lib/subscription-service';

function buildSystemPrompt(
  scenario: {
    situation: string;
    yourRole: string;
    aiRole: string;
    keyExpressions: string[];
    systemPrompt: string | null;
  },
  jlptLevel: string
): string {
  const levelPrompt =
    SYSTEM_PROMPTS.levels[jlptLevel as keyof typeof SYSTEM_PROMPTS.levels] ||
    SYSTEM_PROMPTS.levels.N5;

  if (scenario.systemPrompt) {
    return [
      SYSTEM_PROMPTS.base,
      levelPrompt,
      scenario.systemPrompt,
      SYSTEM_PROMPTS.responseFormat,
    ].join('\n\n');
  }

  const scenarioPrompt = `## シナリオ
- 状況: ${scenario.situation}
- ユーザーの役割: ${scenario.yourRole}
- あなたの役割: ${scenario.aiRole}
${scenario.keyExpressions.length > 0 ? `- キーフレーズ: ${scenario.keyExpressions.join(', ')}` : ''}`;

  return [
    SYSTEM_PROMPTS.base,
    levelPrompt,
    scenarioPrompt,
    SYSTEM_PROMPTS.responseFormat,
  ].join('\n\n');
}

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
        { status: 429, headers: { 'Retry-After': String(Math.ceil((rl.reset - Date.now()) / 1000)) } }
      );
    }

    // AI 사용량 체크
    const aiCheck = await checkAiLimit(user.id, 'chat');
    if (!aiCheck.allowed) {
      return NextResponse.json(
        { error: aiCheck.reason, code: 'AI_LIMIT_EXCEEDED' },
        { status: 429 }
      );
    }

    const body = await request.json();
    const { scenarioId } = body;

    if (!scenarioId) {
      return NextResponse.json(
        { error: 'scenarioId is required' },
        { status: 400 }
      );
    }

    const scenario = await prisma.conversationScenario.findUnique({
      where: { id: scenarioId },
    });
    if (!scenario) {
      return NextResponse.json(
        { error: 'Scenario not found' },
        { status: 404 }
      );
    }

    // Get user's JLPT level
    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: { jlptLevel: true },
    });
    const jlptLevel = dbUser?.jlptLevel || 'N5';

    const systemPrompt = buildSystemPrompt(scenario, jlptLevel);

    // Generate first greeting message from AI
    const { text } = await generateText({
      model: getAIProvider(),
      system: systemPrompt,
      messages: [
        {
          role: 'user',
          content:
            '会話を始めてください。あなたの役割で最初の挨拶をしてください。',
        },
      ],
    });

    // Parse AI response
    let firstMessage: {
      messageJa: string;
      messageKo: string;
      hint: string;
      feedback?: unknown[];
      newVocabulary?: unknown[];
    };
    try {
      // Try to extract JSON from the response (handle markdown code blocks)
      const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
      firstMessage = JSON.parse((jsonMatch?.[1]?.trim() || text.trim()));
    } catch {
      // Fallback if AI doesn't return proper JSON
      firstMessage = {
        messageJa: text,
        messageKo: '(번역을 불러올 수 없습니다)',
        hint: '일본어로 인사해 보세요!',
      };
    }

    // Create conversation record
    const conversation = await prisma.conversation.create({
      data: {
        userId: user.id,
        scenarioId,
        messages: [
          {
            role: 'system',
            content: systemPrompt,
          },
          {
            role: 'user',
            content:
              '会話を始めてください。あなたの役割で最初の挨拶をしてください。',
          },
          {
            role: 'assistant',
            content: text,
          },
        ],
        messageCount: 1,
      },
    });

    return NextResponse.json({
      conversationId: conversation.id,
      firstMessage: {
        messageJa: firstMessage.messageJa,
        messageKo: firstMessage.messageKo,
        hint: firstMessage.hint,
      },
    });
  } catch (err) {
    console.error('Chat start error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
