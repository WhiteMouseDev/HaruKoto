import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { openaiClient } from '@harukoto/ai';

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
    const { text, speed } = body as { text?: string; speed?: number };

    if (!text || text.trim().length === 0) {
      return NextResponse.json(
        { error: '텍스트가 필요합니다' },
        { status: 400 }
      );
    }

    const speech = await openaiClient.audio.speech.create({
      model: 'tts-1',
      voice: 'nova',
      input: text,
      speed: speed || 0.9,
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
