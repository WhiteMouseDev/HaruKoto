import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { openaiClient } from '@harukoto/ai';

const MAX_FILE_SIZE = 4.5 * 1024 * 1024; // 4.5MB

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
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
