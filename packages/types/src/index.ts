export type { User, UserProfile } from './user';
export type { Vocabulary, Grammar, JlptLevel, PartOfSpeech } from './content';
export type {
  QuizSession,
  QuizQuestion,
  QuizAnswer,
  QuizResult,
  QuizType,
  QuizMode,
} from './quiz';
export type {
  Conversation,
  ConversationMessage,
  ConversationReport,
  ScenarioCategory,
  Scenario,
  Difficulty,
} from './conversation';
export type {
  SubscriptionStatus,
  SubscriptionPlan,
  SubscriptionStatusResponse,
  CheckoutResponse,
  PaymentRecord,
  PricingPlan,
} from './subscription';
export type { Streak, DailyProgress, LevelInfo } from './gamification';
export type { ApiError, Pagination, ApiResponse } from './api';

// Auto-generated from apps/api/openapi/openapi.json (do not edit by hand).
// Consumers use: `import type { components } from '@harukoto/types';`
// then: `type Quiz = components['schemas']['QuizResponse'];`
//
// To refresh after backend changes:
//   1. cd apps/api && uv run python scripts/export_openapi.py
//   2. pnpm --filter @harukoto/types gen:api
export type { paths, components, operations } from './generated/api';
