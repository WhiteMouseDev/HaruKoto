const KST_OFFSET = 9 * 60 * 60 * 1000; // UTC+9

/**
 * 한국 시간(KST) 기준 오늘 00:00:00 UTC Date 반환.
 * DB에 저장할 때 KST 날짜 경계를 사용.
 *
 * 예: KST 2026-03-06 02:00 → UTC 2026-03-05 17:00
 *     KST 날짜는 3월 6일 → 반환값: 2026-03-06T00:00:00Z (UTC)
 */
export function getTodayKST(): Date {
  const now = new Date();
  const kstTime = new Date(now.getTime() + KST_OFFSET);
  const year = kstTime.getUTCFullYear();
  const month = kstTime.getUTCMonth();
  const day = kstTime.getUTCDate();
  return new Date(Date.UTC(year, month, day));
}
