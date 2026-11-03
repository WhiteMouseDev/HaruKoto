import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import {
  listSavedQuizzes,
  SavedQuizQueryError,
} from '@/lib/quiz-incomplete-sessions';

export async function GET(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user)
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    return NextResponse.json(
      await listSavedQuizzes(user.id, new URL(request.url).searchParams)
    );
  } catch (error) {
    if (error instanceof SavedQuizQueryError)
      return NextResponse.json({ error: error.message }, { status: 400 });
    console.error('Saved quiz list error:', error);
    return NextResponse.json(
      { error: '저장된 퀴즈를 불러오지 못했어요. 다시 시도해 주세요.' },
      { status: 500 }
    );
  }
}
