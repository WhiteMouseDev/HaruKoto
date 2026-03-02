import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { openaiClient } from '@harukoto/ai';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';

const MAX_FILE_SIZE = 4.5 * 1024 * 1024; // 4.5MB

const ALLOWED_AUDIO_TYPES = new Set([
  'audio/webm',
  'audio/mp3',
  'audio/mpeg',
  'audio/mp4',
  'audio/mpga',
  'audio/wav',
  'audio/x-wav',
  'audio/ogg',
  'audio/flac',
  'audio/x-m4a',
  'video/webm',
]);

const ALLOWED_EXTENSIONS = new Set([
  'webm', 'mp3', 'mp4', 'mpeg', 'mpga', 'wav', 'ogg', 'flac', 'm4a',
]);

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const rl = rateLimit(`stt:${user.id}`, RATE_LIMITS.AI);
    if (!rl.success) {
      return NextResponse.json(
        { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
        { status: 429, headers: { 'Retry-After': String(Math.ceil((rl.reset - Date.now()) / 1000)) } }
      );
    }

    const formData = await request.formData();
    const audioFile = formData.get('audio');

    if (!audioFile || !(audioFile instanceof File)) {
      return NextResponse.json(
        { error: '오디오 파일이 필요합니다' },
        { status: 400 }
      );
    }

    if (audioFile.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { error: '파일 크기는 4.5MB 이하여야 합니다' },
        { status: 400 }
      );
    }

    // Validate audio format
    const extension = audioFile.name.split('.').pop()?.toLowerCase() ?? '';
    const isValidType = ALLOWED_AUDIO_TYPES.has(audioFile.type) || ALLOWED_EXTENSIONS.has(extension);
    if (!isValidType) {
      return NextResponse.json(
        { error: '지원하지 않는 오디오 형식입니다. webm, mp3, wav, ogg, flac, m4a 형식을 사용해주세요.' },
        { status: 400 }
      );
    }

    const transcription = await openaiClient.audio.transcriptions.create({
      file: audioFile,
      model: 'whisper-1',
      language: 'ja',
    });

    return NextResponse.json({ transcription: transcription.text });
  } catch (err) {
    console.error('STT transcribe error:', err);
    return NextResponse.json(
      { error: '음성 변환 중 오류가 발생했습니다' },
      { status: 500 }
    );
  }
}
