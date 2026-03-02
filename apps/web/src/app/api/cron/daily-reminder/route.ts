import { NextResponse } from 'next/server';
import { prisma } from '@harukoto/database';
import { sendPushNotification } from '@/lib/web-push';

// Vercel Cron에서 호출 (매일 오전 9시 KST = 0시 UTC)
export async function GET(request: Request) {
  // Cron 시크릿 검증
  const authHeader = request.headers.get('authorization');
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    // 오늘 아직 학습하지 않은 사용자 중 푸시 구독이 있는 사용자
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const usersWithSubscriptions = await prisma.pushSubscription.findMany({
      select: {
        userId: true,
        user: {
          select: {
            nickname: true,
            streakCount: true,
            lastStudyDate: true,
          },
        },
      },
      distinct: ['userId'],
    });

    let sent = 0;
    let skipped = 0;

    for (const sub of usersWithSubscriptions) {
      const lastStudy = sub.user.lastStudyDate;
      if (lastStudy) {
        const lastDay = new Date(lastStudy);
        lastDay.setHours(0, 0, 0, 0);
        if (lastDay.getTime() === today.getTime()) {
          skipped++;
          continue; // 오늘 이미 학습함
        }
      }

      const name = sub.user.nickname || '학습자';
      const streak = sub.user.streakCount;

      let body: string;
      if (streak > 0) {
        body = `${name}님, ${streak}일 연속 학습 중! 오늘도 이어가세요 🔥`;
      } else {
        body = `${name}님, 오늘의 일본어 학습을 시작해볼까요? 🌸`;
      }

      try {
        await sendPushNotification(sub.userId, {
          title: '하루코토 📚',
          body,
          url: '/',
        });
        sent++;
      } catch {
        // 개별 실패는 무시
      }
    }

    return NextResponse.json({ sent, skipped, total: usersWithSubscriptions.length });
  } catch (err) {
    console.error('Daily reminder cron error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
