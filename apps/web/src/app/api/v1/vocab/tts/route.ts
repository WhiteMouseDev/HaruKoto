import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { generateTTS } from '@harukoto/ai';
import { uploadToGCS } from '@/lib/gcs';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';

const GCS_CDN_URL = process.env.NEXT_PUBLIC_GCS_CDN_URL!;

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
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcmLength, 40);

  return header;
}

// In-memory lock to prevent duplicate generation for same vocabId
const generatingSet = new Set<string>();

export async function GET(request: NextRequest) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const vocabId = request.nextUrl.searchParams.get('id');
    if (!vocabId) {
      return NextResponse.json({ error: 'id 파라미터가 필요합니다' }, { status: 400 });
    }

    // Check DB for cached audioUrl
    const vocab = await prisma.vocabulary.findUnique({
      where: { id: vocabId },
      select: { id: true, word: true, audioUrl: true },
    });

    if (!vocab) {
      return NextResponse.json({ error: '단어를 찾을 수 없습니다' }, { status: 404 });
    }

    // If already cached, return GCS URL
    if (vocab.audioUrl) {
      return NextResponse.json({ audioUrl: vocab.audioUrl });
    }

    // Rate limit TTS generation
    const rl = rateLimit(`tts:${user.id}`, RATE_LIMITS.AI);
    if (!rl.success) {
      return NextResponse.json(
        { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
        { status: 429 }
      );
    }

    // Prevent duplicate concurrent generation
    if (generatingSet.has(vocabId)) {
      return NextResponse.json(
        { error: '음성을 생성 중입니다. 잠시 후 다시 시도해주세요.' },
        { status: 202 }
      );
    }

    generatingSet.add(vocabId);
    try {
      // Generate TTS via Gemini
      const pcmBuffer = await generateTTS(vocab.word);
      const wavHeader = createWavHeader(pcmBuffer.byteLength);
      const wavBuffer = Buffer.concat([wavHeader, pcmBuffer]);

      // Upload to GCS
      const gcsPath = `tts/${vocabId}.wav`;
      await uploadToGCS(gcsPath, wavBuffer, 'audio/wav');

      // Update DB with GCS URL
      const audioUrl = `${GCS_CDN_URL}/${gcsPath}`;
      await prisma.vocabulary.update({
        where: { id: vocabId },
        data: { audioUrl },
      });

      return NextResponse.json({ audioUrl });
    } finally {
      generatingSet.delete(vocabId);
    }
  } catch (err) {
    console.error('Vocab TTS error:', err);
    return NextResponse.json(
      { error: '음성 생성 중 오류가 발생했습니다' },
      { status: 500 }
    );
  }
}
