from app.schemas.auth import OnboardingRequest, OnboardingResponse
from app.schemas.chat import (
    ChatEndRequest,
    ChatEndResponse,
    ChatHistoryItem,
    ChatMessage,
    ChatMessageRequest,
    ChatMessageResponse,
    ChatStartRequest,
    ChatStartResponse,
    ChatTTSRequest,
    LiveFeedbackRequest,
    LiveTokenRequest,
    TranscribeRequest,
)
from app.schemas.common import (
    CamelModel,
    ErrorResponse,
    PaginatedResponse,
    SuccessResponse,
    to_camel,
)
from app.schemas.kana import (
    KanaCharacterResponse,
    KanaProgressResponse,
    KanaQuizAnswerRequest,
    KanaQuizAnswerResponse,
    KanaQuizStartRequest,
    KanaQuizStartResponse,
    KanaStageCompleteRequest,
    KanaStageCompleteResponse,
    KanaStageResponse,
    KanaStat,
)
from app.schemas.missions import (
    MissionClaimRequest,
    MissionClaimResponse,
    MissionResponse,
)
from app.schemas.notification import NotificationResponse, PushSubscribeRequest
from app.schemas.quiz import (
    QuizAnswerRequest,
    QuizAnswerResponse,
    QuizCompleteRequest,
    QuizCompleteResponse,
    QuizOption,
    QuizQuestion,
    QuizStartRequest,
    QuizStartResponse,
    WrongAnswer,
)
from app.schemas.stats import (
    DailyProgressItem,
    DashboardResponse,
    HistoryResponse,
    LevelProgress,
    ProgressStat,
    TodayStats,
    WeeklyStats,
)
from app.schemas.subscription import (
    ActivateRequest,
    AiLimits,
    AiUsage,
    CancelRequest,
    CheckoutRequest,
    CheckoutResponse,
    PaymentHistoryItem,
    PaymentHistoryResponse,
    SubscriptionStatusResponse,
)
from app.schemas.user import UserProfile, UserProfileUpdate, UserStats
from app.schemas.wordbook import (
    WordbookCreateRequest,
    WordbookEntryResponse,
    WordbookListResponse,
    WordbookUpdateRequest,
)

__all__ = [
    # common
    "CamelModel",
    "ErrorResponse",
    "PaginatedResponse",
    "SuccessResponse",
    "to_camel",
    # auth
    "OnboardingRequest",
    "OnboardingResponse",
    # user
    "UserProfile",
    "UserProfileUpdate",
    "UserStats",
    # quiz
    "QuizOption",
    "QuizQuestion",
    "WrongAnswer",
    "QuizStartRequest",
    "QuizStartResponse",
    "QuizAnswerRequest",
    "QuizAnswerResponse",
    "QuizCompleteRequest",
    "QuizCompleteResponse",
    # chat
    "ChatMessage",
    "ChatStartRequest",
    "ChatStartResponse",
    "ChatMessageRequest",
    "ChatMessageResponse",
    "ChatEndRequest",
    "ChatEndResponse",
    "ChatHistoryItem",
    "ChatTTSRequest",
    "TranscribeRequest",
    "LiveTokenRequest",
    "LiveFeedbackRequest",
    # kana
    "KanaCharacterResponse",
    "KanaStat",
    "KanaStageResponse",
    "KanaProgressResponse",
    "KanaQuizStartRequest",
    "KanaQuizStartResponse",
    "KanaQuizAnswerRequest",
    "KanaQuizAnswerResponse",
    "KanaStageCompleteRequest",
    "KanaStageCompleteResponse",
    # missions
    "MissionResponse",
    "MissionClaimRequest",
    "MissionClaimResponse",
    # stats
    "TodayStats",
    "WeeklyStats",
    "LevelProgress",
    "ProgressStat",
    "DashboardResponse",
    "DailyProgressItem",
    "HistoryResponse",
    # wordbook
    "WordbookEntryResponse",
    "WordbookCreateRequest",
    "WordbookUpdateRequest",
    "WordbookListResponse",
    # subscription
    "AiUsage",
    "AiLimits",
    "SubscriptionStatusResponse",
    "CheckoutRequest",
    "CheckoutResponse",
    "ActivateRequest",
    "CancelRequest",
    "PaymentHistoryItem",
    "PaymentHistoryResponse",
    # notification
    "NotificationResponse",
    "PushSubscribeRequest",
]
