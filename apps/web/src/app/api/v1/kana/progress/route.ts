import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const [hiraganaTotal, katakanaTotal, hiraganaLearned, katakanaLearned, hiraganaMastered, katakanaMastered] =
      await Promise.all([
        prisma.kanaCharacter.count({
          where: { kanaType: 'HIRAGANA' },
        }),
        prisma.kanaCharacter.count({
          where: { kanaType: 'KATAKANA' },
        }),
        prisma.userKanaProgress.count({
          where: {
            userId: user.id,
            kana: { kanaType: 'HIRAGANA' },
          },
        }),
        prisma.userKanaProgress.count({
          where: {
            userId: user.id,
            kana: { kanaType: 'KATAKANA' },
          },
        }),
        prisma.userKanaProgress.count({
          where: {
            userId: user.id,
            mastered: true,
            kana: { kanaType: 'HIRAGANA' },
          },
        }),
        prisma.userKanaProgress.count({
          where: {
            userId: user.id,
            mastered: true,
            kana: { kanaType: 'KATAKANA' },
          },
        }),
      ]);

    return NextResponse.json({
      hiragana: {
        learned: hiraganaLearned,
        mastered: hiraganaMastered,
        total: hiraganaTotal,
        pct: hiraganaTotal > 0 ? Math.round((hiraganaLearned / hiraganaTotal) * 100) : 0,
      },
      katakana: {
        learned: katakanaLearned,
        mastered: katakanaMastered,
        total: katakanaTotal,
        pct: katakanaTotal > 0 ? Math.round((katakanaLearned / katakanaTotal) * 100) : 0,
      },
    });
  } catch (err) {
    console.error('Kana progress GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
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

    const body = await request.json();
    const { kanaId, learned } = body;

    if (!kanaId) {
      return NextResponse.json(
        { error: 'kanaId is required' },
        { status: 400 }
      );
    }

    // Verify kana character exists
    const kana = await prisma.kanaCharacter.findUnique({
      where: { id: kanaId },
    });
    if (!kana) {
      return NextResponse.json(
        { error: 'Kana character not found' },
        { status: 404 }
      );
    }

    // Upsert user kana progress
    const progress = await prisma.userKanaProgress.upsert({
      where: {
        userId_kanaId: { userId: user.id, kanaId },
      },
      update: {
        lastReviewedAt: new Date(),
        ...(learned
          ? { correctCount: { increment: 1 }, streak: { increment: 1 } }
          : { incorrectCount: { increment: 1 }, streak: 0 }),
      },
      create: {
        userId: user.id,
        kanaId,
        correctCount: learned ? 1 : 0,
        incorrectCount: learned ? 0 : 1,
        streak: learned ? 1 : 0,
        lastReviewedAt: new Date(),
      },
    });

    // Update mastered status if streak >= 3
    if (progress.streak >= 3 && !progress.mastered) {
      await prisma.userKanaProgress.update({
        where: { id: progress.id },
        data: { mastered: true },
      });
    }

    // Update DailyProgress.kanaLearned
    const today = getTodayKST();

    await prisma.dailyProgress.upsert({
      where: { userId_date: { userId: user.id, date: today } },
      update: { kanaLearned: { increment: 1 } },
      create: {
        userId: user.id,
        date: today,
        kanaLearned: 1,
      },
    });

    return NextResponse.json({ success: true, progress });
  } catch (err) {
    console.error('Kana progress POST error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
