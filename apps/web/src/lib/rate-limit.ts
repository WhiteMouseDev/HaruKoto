/**
 * In-memory sliding window rate limiter.
 * 서버리스 환경에서도 동작하며, 인스턴스 단위로 제한.
 * (프로덕션 스케일에서는 Redis 기반으로 교체 권장)
 */

type RateLimitEntry = {
  timestamps: number[];
};

const store = new Map<string, RateLimitEntry>();

// 오래된 엔트리 정리 (메모리 누수 방지)
const CLEANUP_INTERVAL = 60_000; // 1분
let lastCleanup = Date.now();

function cleanup(windowMs: number) {
  const now = Date.now();
  if (now - lastCleanup < CLEANUP_INTERVAL) return;
  lastCleanup = now;

  const cutoff = now - windowMs;
  for (const [key, entry] of store) {
    entry.timestamps = entry.timestamps.filter((t) => t > cutoff);
    if (entry.timestamps.length === 0) {
      store.delete(key);
    }
  }
}

type RateLimitResult = {
  success: boolean;
  remaining: number;
  reset: number;
};

type RateLimitConfig = {
  /** 허용 요청 수 */
  limit: number;
  /** 윈도우 크기 (밀리초) */
  windowMs: number;
};

/**
 * Rate limit 체크
 * @param key - 고유 식별자 (보통 userId 또는 IP)
 * @param config - limit/windowMs 설정
 */
export function rateLimit(key: string, config: RateLimitConfig): RateLimitResult {
  const { limit, windowMs } = config;
  const now = Date.now();
  const cutoff = now - windowMs;

  cleanup(windowMs);

  let entry = store.get(key);
  if (!entry) {
    entry = { timestamps: [] };
    store.set(key, entry);
  }

  // 윈도우 밖 타임스탬프 제거
  entry.timestamps = entry.timestamps.filter((t) => t > cutoff);

  if (entry.timestamps.length >= limit) {
    const oldestInWindow = entry.timestamps[0];
    return {
      success: false,
      remaining: 0,
      reset: oldestInWindow + windowMs,
    };
  }

  entry.timestamps.push(now);

  return {
    success: true,
    remaining: limit - entry.timestamps.length,
    reset: now + windowMs,
  };
}

/** 사전 정의된 Rate Limit 설정 */
export const RATE_LIMITS = {
  /** AI API 호출 (TTS, STT, 채팅) — 분당 20회 */
  AI: { limit: 20, windowMs: 60_000 },
  /** 일반 API — 분당 60회 */
  API: { limit: 60, windowMs: 60_000 },
  /** 인증 관련 — 분당 10회 */
  AUTH: { limit: 10, windowMs: 60_000 },
  /** Live API 토큰 발급 — 분당 5회 */
  LIVE_TOKEN: { limit: 5, windowMs: 60_000 },
} as const;
