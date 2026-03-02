import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getGoogleGenAI } from '@harukoto/ai';
import { rateLimit, RATE_LIMITS } from '@/lib/rate-limit';

// Ephemeral tokens require BidiGenerateContentConstrained + access_token param
const WS_BASE_URI =
  'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained';

export async function POST() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const rl = rateLimit(`live-token:${user.id}`, RATE_LIMITS.LIVE_TOKEN);
    if (!rl.success) {
      return NextResponse.json(
        { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
        {
          status: 429,
          headers: {
            'Retry-After': String(
              Math.ceil((rl.reset - Date.now()) / 1000)
            ),
          },
        }
      );
    }

    const genai = getGoogleGenAI();

    // expireTime must be ISO 8601 / RFC 3339 format
    const expireTime = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    const authToken = await genai.authTokens.create({
      config: { expireTime },
    });

    const token = authToken.name;

    if (!token) {
      return NextResponse.json(
        { error: 'Failed to create ephemeral token' },
        { status: 500 }
      );
    }

    return NextResponse.json({ token, wsUri: WS_BASE_URI });
  } catch (err) {
    console.error('Live token error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
