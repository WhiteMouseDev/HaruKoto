import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { generateText } from 'ai';
import { getAIProvider, SYSTEM_PROMPTS } from '@harukoto/ai';

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
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
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
      const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/) || [
        null,
        text,
      ];
      firstMessage = JSON.parse(jsonMatch[1]!.trim());
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
