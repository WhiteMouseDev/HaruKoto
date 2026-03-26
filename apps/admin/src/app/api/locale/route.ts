import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

const validLocales = ['ja', 'ko', 'en'] as const;
type ValidLocale = (typeof validLocales)[number];

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { locale } = body as { locale?: string };

  if (!locale || !validLocales.includes(locale as ValidLocale)) {
    return NextResponse.json(
      { error: `Invalid locale. Must be one of: ${validLocales.join(', ')}` },
      { status: 400 }
    );
  }

  const cookieStore = await cookies();
  cookieStore.set('NEXT_LOCALE', locale, {
    path: '/',
    maxAge: 365 * 24 * 60 * 60,
    sameSite: 'lax',
  });

  return NextResponse.json({ locale });
}
