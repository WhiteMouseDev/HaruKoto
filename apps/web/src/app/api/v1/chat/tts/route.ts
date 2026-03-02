import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { openaiClient } from '@harukoto/ai';
import { z } from 'zod';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';

const ttsInputSchema = z.object({
  text: z.string().min(1, '텍스트가 필요합니다').max(4096, '텍스트는 4096자 이하여야 합니다'),
  speed: z.number().min(0.25).max(4.0).optional(),
});

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const rl = rateLimit(`tts:${user.id}`, RATE_LIMITS.AI);
    if (!rl.success) {
      return NextResponse.json(
        { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
        { status: 429, headers: { 'Retry-After': String(Math.ceil((rl.reset - Date.now()) / 1000)) } }
      );
    }

    const body = await request.json();
    const parsed = ttsInputSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json(
        { error: parsed.error.issues[0]?.message ?? '입력값이 올바르지 않습니다' },
        { status: 400 }
      );
    }

    const { text, speed } = parsed.data;

    const speech = await openaiClient.audio.speech.create({
      model: 'tts-1',
      voice: 'nova',
      input: text,
      speed: speed ?? 0.9,
    });

    return new Response(speech.body, {
      headers: {
        'Content-Type': 'audio/mpeg',
      },
    });
  } catch (err) {
    console.error('TTS error:', err);
    return NextResponse.json(
      { error: '음성 생성 중 오류가 발생했습니다' },
      { status: 500 }
    );
  }
}
