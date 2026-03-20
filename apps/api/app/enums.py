import enum


class JlptLevel(str, enum.Enum):
    ABSOLUTE_ZERO = "ABSOLUTE_ZERO"
    N5 = "N5"
    N4 = "N4"
    N3 = "N3"
    N2 = "N2"
    N1 = "N1"


def effective_jlpt_level(level: "JlptLevel") -> "JlptLevel":
    """ABSOLUTE_ZERO는 콘텐츠 조회 시 N5로 매핑."""
    if level == JlptLevel.ABSOLUTE_ZERO:
        return JlptLevel.N5
    return level


class PartOfSpeech(str, enum.Enum):
    NOUN = "NOUN"
    VERB = "VERB"
    I_ADJECTIVE = "I_ADJECTIVE"
    NA_ADJECTIVE = "NA_ADJECTIVE"
    ADVERB = "ADVERB"
    PARTICLE = "PARTICLE"
    CONJUNCTION = "CONJUNCTION"
    COUNTER = "COUNTER"
    EXPRESSION = "EXPRESSION"
    PREFIX = "PREFIX"
    SUFFIX = "SUFFIX"


class QuizType(str, enum.Enum):
    VOCABULARY = "VOCABULARY"
    GRAMMAR = "GRAMMAR"
    KANJI = "KANJI"
    LISTENING = "LISTENING"
    KANA = "KANA"
    CLOZE = "CLOZE"
    SENTENCE_ARRANGE = "SENTENCE_ARRANGE"


class KanaType(str, enum.Enum):
    HIRAGANA = "HIRAGANA"
    KATAKANA = "KATAKANA"


class ScenarioCategory(str, enum.Enum):
    TRAVEL = "TRAVEL"
    DAILY = "DAILY"
    BUSINESS = "BUSINESS"
    FREE = "FREE"


class Difficulty(str, enum.Enum):
    BEGINNER = "BEGINNER"
    INTERMEDIATE = "INTERMEDIATE"
    ADVANCED = "ADVANCED"


class UserGoal(str, enum.Enum):
    # Legacy (하위 호환)
    JLPT_N5 = "JLPT_N5"
    JLPT_N4 = "JLPT_N4"
    JLPT_N3 = "JLPT_N3"
    JLPT_N2 = "JLPT_N2"
    JLPT_N1 = "JLPT_N1"
    BUSINESS = "BUSINESS"
    # New goals (v2)
    TRAVEL = "TRAVEL"
    CONTENT = "CONTENT"
    JLPT = "JLPT"
    WORK = "WORK"
    STUDY_ABROAD = "STUDY_ABROAD"
    LIVING = "LIVING"
    HOBBY = "HOBBY"


class WordbookSource(str, enum.Enum):
    QUIZ = "QUIZ"
    CONVERSATION = "CONVERSATION"
    MANUAL = "MANUAL"


class SubscriptionPlan(str, enum.Enum):
    FREE = "FREE"
    MONTHLY = "MONTHLY"
    YEARLY = "YEARLY"


class SubscriptionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"
    PAST_DUE = "PAST_DUE"


class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"
    CANCELLED = "CANCELLED"


class ConversationType(str, enum.Enum):
    VOICE = "VOICE"
    TEXT = "TEXT"
