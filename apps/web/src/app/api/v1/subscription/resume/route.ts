import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { resumeSubscription } from '@/lib/subscription-service';

export async function POST() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    await resumeSubscription(user.id);

    return NextResponse.json({ success: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    console.error('Resume error:', err);
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
