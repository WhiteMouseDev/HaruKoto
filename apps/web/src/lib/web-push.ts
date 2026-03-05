import webpush from 'web-push';
import { prisma } from '@harukoto/database';

// VAPID 키 설정
const VAPID_PUBLIC_KEY = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!;
const VAPID_PRIVATE_KEY = process.env.VAPID_PRIVATE_KEY!;
const VAPID_SUBJECT = process.env.VAPID_SUBJECT || 'mailto:whitemousedev@whitemouse.dev';

if (VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
}

/**
 * 특정 사용자에게 푸시 알림 전송
 */
export async function sendPushNotification(
  userId: string,
  payload: { title: string; body: string; icon?: string; url?: string }
) {
  const subscriptions = await prisma.pushSubscription.findMany({
    where: { userId },
  });

  const results = await Promise.allSettled(
    subscriptions.map(async (sub) => {
      try {
        await webpush.sendNotification(
          {
            endpoint: sub.endpoint,
            keys: {
              p256dh: sub.p256dh,
              auth: sub.auth,
            },
          },
          JSON.stringify(payload)
        );
      } catch (error: unknown) {
        // 구독 만료 시 삭제 (410 Gone, 404 Not Found)
        if (
          error instanceof webpush.WebPushError &&
          (error.statusCode === 410 || error.statusCode === 404)
        ) {
          await prisma.pushSubscription.delete({
            where: { id: sub.id },
          });
        }
        throw error;
      }
    })
  );

  const sent = results.filter((r) => r.status === 'fulfilled').length;
  const failed = results.filter((r) => r.status === 'rejected').length;

  return { sent, failed };
}
