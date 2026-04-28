from dataclasses import dataclass


@dataclass(frozen=True)
class _Rewards:
    QUIZ_XP_PER_CORRECT: int = 10
    CONVERSATION_COMPLETE_XP: int = 20


@dataclass(frozen=True)
class _AccuracyThresholds:
    GREAT: int = 80
    GOOD: int = 50


@dataclass(frozen=True)
class _QuizConfig:
    DEFAULT_COUNT: int = 10
    ACCURACY_THRESHOLDS: _AccuracyThresholds = _AccuracyThresholds()
    REVIEW_RATIO: float = 0.6
    WRONG_OPTIONS_COUNT: int = 3


@dataclass(frozen=True)
class _SpeedThresholds:
    INSTANT: int = 3
    QUICK: int = 8


@dataclass(frozen=True)
class _SrsConfig:
    SPEED_THRESHOLDS: _SpeedThresholds = _SpeedThresholds()
    INITIAL_INTERVALS: tuple[int, int] = (1, 3)
    MASTERY_INTERVAL: int = 21
    MIN_EASE_FACTOR: float = 1.3
    INCORRECT_PENALTY: float = 0.2
    REVIEW_DELAY_MINUTES: int = 10
    LAPSE_MULTIPLIER: float = 0.1
    LAPSE_MAX_INTERVAL: int = 7
    INSTANT_BONUS: float = 1.1


@dataclass(frozen=True)
class _SmartQuizConfig:
    DAILY_GOAL: int = 20
    MAX_RETRY_RATIO: float = 0.2
    MAX_REVIEW_RATIO: float = 0.75
    MIN_NEW_RATIO: float = 0.1
    DEBT_SEVERE_THRESHOLD: int = 30
    DEBT_MILD_THRESHOLD: int = 10


@dataclass(frozen=True)
class _KanaRewards:
    STAGE_COMPLETE_XP: int = 30
    QUIZ_PERFECT_XP: int = 20
    QUIZ_PASS_XP: int = 10


@dataclass(frozen=True)
class _Pagination:
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 50


@dataclass(frozen=True)
class _AiTierLimits:
    CHAT_COUNT: int = 0
    CHAT_SECONDS: int = 0
    CALL_COUNT: int = 0
    CALL_SECONDS: int = 0


@dataclass(frozen=True)
class _AiLimits:
    FREE: _AiTierLimits = _AiTierLimits(CHAT_COUNT=3, CHAT_SECONDS=300, CALL_COUNT=30, CALL_SECONDS=900)
    PREMIUM: _AiTierLimits = _AiTierLimits(CHAT_COUNT=50, CHAT_SECONDS=600, CALL_COUNT=300, CALL_SECONDS=7200)


@dataclass(frozen=True)
class _Prices:
    MONTHLY: int = 4900
    YEARLY: int = 39900


@dataclass(frozen=True)
class _RateLimitTier:
    max_requests: int
    window_seconds: int


@dataclass(frozen=True)
class _RateLimits:
    AI: _RateLimitTier = _RateLimitTier(max_requests=20, window_seconds=60)
    API: _RateLimitTier = _RateLimitTier(max_requests=60, window_seconds=60)
    AUTH: _RateLimitTier = _RateLimitTier(max_requests=10, window_seconds=60)
    LIVE_TOKEN: _RateLimitTier = _RateLimitTier(max_requests=5, window_seconds=60)


REWARDS = _Rewards()
QUIZ_CONFIG = _QuizConfig()
SRS_CONFIG = _SrsConfig()
SMART_QUIZ = _SmartQuizConfig()
KANA_REWARDS = _KanaRewards()
PAGINATION = _Pagination()
AI_LIMITS = _AiLimits()
PRICES = _Prices()
RATE_LIMITS = _RateLimits()
