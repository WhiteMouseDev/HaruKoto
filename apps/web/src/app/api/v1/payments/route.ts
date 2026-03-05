import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getPaymentHistory } from '@/lib/subscription-service';

export async function GET(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const page = Math.max(1, parseInt(searchParams.get('page') ?? '1', 10));

    const result = await getPaymentHistory(user.id, page);

    return NextResponse.json(result);
  } catch (err) {
    console.error('Payments error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
