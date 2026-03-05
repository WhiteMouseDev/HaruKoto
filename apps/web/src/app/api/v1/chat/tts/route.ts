import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { generateTTS } from '@harukoto/ai';
import { z } from 'zod';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';

const ttsInputSchema = z.object({
  text: z.string().min(1, '텍스트가 필요합니다').max(4096, '텍스트는 4096자 이하여야 합니다'),
});

/**
 * Create a WAV header for raw PCM data (24kHz, 16-bit, mono).
 */
function createWavHeader(pcmLength: number): Buffer {
  const header = Buffer.alloc(44);
  const sampleRate = 24000;
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
  const blockAlign = numChannels * (bitsPerSample / 8);

  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcmLength, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16); // PCM chunk size
  header.writeUInt16LE(1, 20); // PCM format
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcmLength, 40);

  return header;
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

    const { text } = parsed.data;

    const pcmBuffer = await generateTTS(text);
    const wavHeader = createWavHeader(pcmBuffer.byteLength);
    const wavBuffer = Buffer.concat([wavHeader, pcmBuffer]);

    return new Response(wavBuffer, {
      headers: {
        'Content-Type': 'audio/wav',
        'Content-Length': String(wavBuffer.byteLength),
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
