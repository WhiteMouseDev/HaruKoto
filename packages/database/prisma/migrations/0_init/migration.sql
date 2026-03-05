-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "JlptLevel" AS ENUM ('N5', 'N4', 'N3', 'N2', 'N1');

-- CreateEnum
CREATE TYPE "PartOfSpeech" AS ENUM ('NOUN', 'VERB', 'I_ADJECTIVE', 'NA_ADJECTIVE', 'ADVERB', 'PARTICLE', 'CONJUNCTION', 'COUNTER', 'EXPRESSION', 'PREFIX', 'SUFFIX');

-- CreateEnum
CREATE TYPE "QuizType" AS ENUM ('VOCABULARY', 'GRAMMAR', 'KANJI', 'LISTENING', 'KANA', 'CLOZE', 'SENTENCE_ARRANGE');

-- CreateEnum
CREATE TYPE "KanaType" AS ENUM ('HIRAGANA', 'KATAKANA');

-- CreateEnum
CREATE TYPE "ScenarioCategory" AS ENUM ('TRAVEL', 'DAILY', 'BUSINESS', 'FREE');

-- CreateEnum
CREATE TYPE "Difficulty" AS ENUM ('BEGINNER', 'INTERMEDIATE', 'ADVANCED');

-- CreateEnum
CREATE TYPE "UserGoal" AS ENUM ('JLPT_N5', 'JLPT_N4', 'JLPT_N3', 'JLPT_N2', 'JLPT_N1', 'TRAVEL', 'BUSINESS', 'HOBBY');

-- CreateEnum
CREATE TYPE "WordbookSource" AS ENUM ('QUIZ', 'CONVERSATION', 'MANUAL');

-- CreateEnum
CREATE TYPE "SubscriptionPlan" AS ENUM ('FREE', 'MONTHLY', 'YEARLY');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('ACTIVE', 'CANCELLED', 'EXPIRED', 'PAST_DUE');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ConversationType" AS ENUM ('VOICE', 'TEXT');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "nickname" TEXT,
    "avatar_url" TEXT,
    "jlpt_level" "JlptLevel" NOT NULL DEFAULT 'N5',
    "goal" "UserGoal",
    "daily_goal" INTEGER NOT NULL DEFAULT 10,
    "experience_points" INTEGER NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "streak_count" INTEGER NOT NULL DEFAULT 0,
    "longest_streak" INTEGER NOT NULL DEFAULT 0,
    "last_study_date" TIMESTAMP(3),
    "is_premium" BOOLEAN NOT NULL DEFAULT false,
    "subscription_expires_at" TIMESTAMP(3),
    "call_settings" JSONB DEFAULT '{}',
    "show_kana" BOOLEAN NOT NULL DEFAULT false,
    "onboarding_completed" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vocabularies" (
    "id" UUID NOT NULL,
    "jlpt_level" "JlptLevel" NOT NULL,
    "word" TEXT NOT NULL,
    "reading" TEXT NOT NULL,
    "meaning_ko" TEXT NOT NULL,
    "example_sentence" TEXT,
    "example_reading" TEXT,
    "example_translation" TEXT,
    "part_of_speech" "PartOfSpeech" NOT NULL,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "audio_url" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vocabularies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "grammars" (
    "id" UUID NOT NULL,
    "jlpt_level" "JlptLevel" NOT NULL,
    "pattern" TEXT NOT NULL,
    "meaning_ko" TEXT NOT NULL,
    "explanation" TEXT NOT NULL,
    "example_sentences" JSONB NOT NULL DEFAULT '[]',
    "related_grammar_ids" UUID[] DEFAULT ARRAY[]::UUID[],
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "grammars_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quiz_sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "quiz_type" "QuizType" NOT NULL,
    "jlpt_level" "JlptLevel" NOT NULL,
    "total_questions" INTEGER NOT NULL DEFAULT 0,
    "correct_count" INTEGER NOT NULL DEFAULT 0,
    "questions_data" JSONB,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "quiz_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quiz_answers" (
    "id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "question_id" UUID NOT NULL,
    "question_type" "QuizType" NOT NULL,
    "selected_option_id" TEXT NOT NULL,
    "is_correct" BOOLEAN NOT NULL,
    "time_spent_seconds" INTEGER NOT NULL DEFAULT 0,
    "answered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quiz_answers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cloze_questions" (
    "id" UUID NOT NULL,
    "sentence" TEXT NOT NULL,
    "translation" TEXT NOT NULL,
    "correct_answer" TEXT NOT NULL,
    "options" JSONB NOT NULL,
    "explanation" TEXT NOT NULL,
    "grammar_point" TEXT,
    "jlpt_level" "JlptLevel" NOT NULL,
    "difficulty" INTEGER NOT NULL DEFAULT 1,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cloze_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sentence_arrange_questions" (
    "id" UUID NOT NULL,
    "korean_sentence" TEXT NOT NULL,
    "japanese_sentence" TEXT NOT NULL,
    "tokens" JSONB NOT NULL,
    "explanation" TEXT NOT NULL,
    "grammar_point" TEXT,
    "jlpt_level" "JlptLevel" NOT NULL,
    "difficulty" INTEGER NOT NULL DEFAULT 1,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sentence_arrange_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conversation_scenarios" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "title_ja" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "category" "ScenarioCategory" NOT NULL,
    "difficulty" "Difficulty" NOT NULL,
    "estimated_minutes" INTEGER NOT NULL,
    "key_expressions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "situation" TEXT NOT NULL,
    "your_role" TEXT NOT NULL,
    "ai_role" TEXT NOT NULL,
    "system_prompt" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "conversation_scenarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conversations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "scenario_id" UUID,
    "character_id" UUID,
    "type" "ConversationType" NOT NULL DEFAULT 'TEXT',
    "messages" JSONB NOT NULL DEFAULT '[]',
    "feedback_summary" JSONB,
    "message_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMP(3),

    CONSTRAINT "conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_achievements" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "achievement_type" TEXT NOT NULL,
    "achieved_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB,

    CONSTRAINT "user_achievements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_missions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "mission_type" TEXT NOT NULL,
    "target_count" INTEGER NOT NULL,
    "current_count" INTEGER NOT NULL DEFAULT 0,
    "is_completed" BOOLEAN NOT NULL DEFAULT false,
    "reward_claimed" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "daily_missions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_progress" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "words_studied" INTEGER NOT NULL DEFAULT 0,
    "quizzes_completed" INTEGER NOT NULL DEFAULT 0,
    "correct_answers" INTEGER NOT NULL DEFAULT 0,
    "total_answers" INTEGER NOT NULL DEFAULT 0,
    "conversation_count" INTEGER NOT NULL DEFAULT 0,
    "study_time_seconds" INTEGER NOT NULL DEFAULT 0,
    "xp_earned" INTEGER NOT NULL DEFAULT 0,
    "kana_learned" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "daily_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_vocab_progress" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "vocabulary_id" UUID NOT NULL,
    "correct_count" INTEGER NOT NULL DEFAULT 0,
    "incorrect_count" INTEGER NOT NULL DEFAULT 0,
    "streak" INTEGER NOT NULL DEFAULT 0,
    "ease_factor" DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    "interval" INTEGER NOT NULL DEFAULT 0,
    "next_review_at" TIMESTAMP(3),
    "last_reviewed_at" TIMESTAMP(3),
    "mastered" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_vocab_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_grammar_progress" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "grammar_id" UUID NOT NULL,
    "correct_count" INTEGER NOT NULL DEFAULT 0,
    "incorrect_count" INTEGER NOT NULL DEFAULT 0,
    "streak" INTEGER NOT NULL DEFAULT 0,
    "ease_factor" DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    "interval" INTEGER NOT NULL DEFAULT 0,
    "next_review_at" TIMESTAMP(3),
    "last_reviewed_at" TIMESTAMP(3),
    "mastered" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_grammar_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "emoji" TEXT,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "push_subscriptions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "endpoint" TEXT NOT NULL,
    "p256dh" TEXT NOT NULL,
    "auth" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wordbook_entries" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "word" TEXT NOT NULL,
    "reading" TEXT NOT NULL,
    "meaning_ko" TEXT NOT NULL,
    "source" "WordbookSource" NOT NULL DEFAULT 'MANUAL',
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wordbook_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_characters" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "name_ja" TEXT NOT NULL,
    "name_romaji" TEXT NOT NULL,
    "gender" TEXT NOT NULL,
    "age_description" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "relationship" TEXT NOT NULL,
    "background_story" TEXT NOT NULL,
    "personality" TEXT NOT NULL,
    "voice_name" TEXT NOT NULL,
    "voice_backup" TEXT,
    "speech_style" TEXT NOT NULL,
    "target_level" TEXT NOT NULL,
    "silence_ms" INTEGER NOT NULL DEFAULT 1200,
    "tier" TEXT NOT NULL DEFAULT 'default',
    "unlock_condition" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "avatar_emoji" TEXT NOT NULL,
    "avatar_url" TEXT,
    "gradient" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_characters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kana_characters" (
    "id" UUID NOT NULL,
    "kana_type" "KanaType" NOT NULL,
    "character" TEXT NOT NULL,
    "romaji" TEXT NOT NULL,
    "pronunciation" TEXT NOT NULL,
    "row" TEXT NOT NULL,
    "column" TEXT NOT NULL,
    "stroke_count" INTEGER NOT NULL,
    "stroke_order" JSONB,
    "audio_url" TEXT,
    "example_word" TEXT,
    "example_reading" TEXT,
    "example_meaning" TEXT,
    "category" TEXT NOT NULL DEFAULT 'basic',
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kana_characters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_kana_progress" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kana_id" UUID NOT NULL,
    "correct_count" INTEGER NOT NULL DEFAULT 0,
    "incorrect_count" INTEGER NOT NULL DEFAULT 0,
    "streak" INTEGER NOT NULL DEFAULT 0,
    "mastered" BOOLEAN NOT NULL DEFAULT false,
    "last_reviewed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_kana_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kana_learning_stages" (
    "id" UUID NOT NULL,
    "kana_type" "KanaType" NOT NULL,
    "stage_number" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "characters" TEXT[],
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kana_learning_stages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_kana_stages" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "stage_id" UUID NOT NULL,
    "is_unlocked" BOOLEAN NOT NULL DEFAULT false,
    "is_completed" BOOLEAN NOT NULL DEFAULT false,
    "quiz_score" INTEGER,
    "completed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_kana_stages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_favorite_characters" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "character_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_favorite_characters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_character_unlocks" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "character_id" UUID NOT NULL,
    "unlocked_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_character_unlocks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "plan" "SubscriptionPlan" NOT NULL DEFAULT 'FREE',
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "billing_key" TEXT,
    "portone_customer_id" TEXT,
    "current_period_start" TIMESTAMP(3) NOT NULL,
    "current_period_end" TIMESTAMP(3) NOT NULL,
    "cancelled_at" TIMESTAMP(3),
    "cancel_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "subscription_id" UUID,
    "portone_payment_id" TEXT,
    "amount" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'KRW',
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "plan" "SubscriptionPlan" NOT NULL,
    "fail_reason" TEXT,
    "paid_at" TIMESTAMP(3),
    "refunded_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_ai_usage" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "chat_count" INTEGER NOT NULL DEFAULT 0,
    "chat_seconds" INTEGER NOT NULL DEFAULT 0,
    "call_count" INTEGER NOT NULL DEFAULT 0,
    "call_seconds" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "daily_ai_usage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "vocabularies_jlpt_level_idx" ON "vocabularies"("jlpt_level");

-- CreateIndex
CREATE INDEX "vocabularies_part_of_speech_idx" ON "vocabularies"("part_of_speech");

-- CreateIndex
CREATE INDEX "grammars_jlpt_level_idx" ON "grammars"("jlpt_level");

-- CreateIndex
CREATE INDEX "quiz_sessions_user_id_idx" ON "quiz_sessions"("user_id");

-- CreateIndex
CREATE INDEX "quiz_sessions_user_id_jlpt_level_idx" ON "quiz_sessions"("user_id", "jlpt_level");

-- CreateIndex
CREATE INDEX "quiz_answers_session_id_idx" ON "quiz_answers"("session_id");

-- CreateIndex
CREATE INDEX "cloze_questions_jlpt_level_idx" ON "cloze_questions"("jlpt_level");

-- CreateIndex
CREATE INDEX "cloze_questions_jlpt_level_difficulty_idx" ON "cloze_questions"("jlpt_level", "difficulty");

-- CreateIndex
CREATE INDEX "sentence_arrange_questions_jlpt_level_idx" ON "sentence_arrange_questions"("jlpt_level");

-- CreateIndex
CREATE INDEX "sentence_arrange_questions_jlpt_level_difficulty_idx" ON "sentence_arrange_questions"("jlpt_level", "difficulty");

-- CreateIndex
CREATE INDEX "conversation_scenarios_category_idx" ON "conversation_scenarios"("category");

-- CreateIndex
CREATE INDEX "conversation_scenarios_difficulty_idx" ON "conversation_scenarios"("difficulty");

-- CreateIndex
CREATE INDEX "conversations_user_id_idx" ON "conversations"("user_id");

-- CreateIndex
CREATE INDEX "conversations_user_id_created_at_idx" ON "conversations"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "conversations_character_id_idx" ON "conversations"("character_id");

-- CreateIndex
CREATE INDEX "user_achievements_user_id_idx" ON "user_achievements"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_achievements_user_id_achievement_type_key" ON "user_achievements"("user_id", "achievement_type");

-- CreateIndex
CREATE INDEX "daily_missions_user_id_date_idx" ON "daily_missions"("user_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "daily_missions_user_id_date_mission_type_key" ON "daily_missions"("user_id", "date", "mission_type");

-- CreateIndex
CREATE INDEX "daily_progress_user_id_date_idx" ON "daily_progress"("user_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "daily_progress_user_id_date_key" ON "daily_progress"("user_id", "date");

-- CreateIndex
CREATE INDEX "user_vocab_progress_user_id_next_review_at_idx" ON "user_vocab_progress"("user_id", "next_review_at");

-- CreateIndex
CREATE INDEX "user_vocab_progress_user_id_mastered_idx" ON "user_vocab_progress"("user_id", "mastered");

-- CreateIndex
CREATE UNIQUE INDEX "user_vocab_progress_user_id_vocabulary_id_key" ON "user_vocab_progress"("user_id", "vocabulary_id");

-- CreateIndex
CREATE INDEX "user_grammar_progress_user_id_next_review_at_idx" ON "user_grammar_progress"("user_id", "next_review_at");

-- CreateIndex
CREATE INDEX "user_grammar_progress_user_id_mastered_idx" ON "user_grammar_progress"("user_id", "mastered");

-- CreateIndex
CREATE UNIQUE INDEX "user_grammar_progress_user_id_grammar_id_key" ON "user_grammar_progress"("user_id", "grammar_id");

-- CreateIndex
CREATE INDEX "notifications_user_id_is_read_idx" ON "notifications"("user_id", "is_read");

-- CreateIndex
CREATE UNIQUE INDEX "push_subscriptions_user_id_endpoint_key" ON "push_subscriptions"("user_id", "endpoint");

-- CreateIndex
CREATE INDEX "wordbook_entries_user_id_idx" ON "wordbook_entries"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "wordbook_entries_user_id_word_key" ON "wordbook_entries"("user_id", "word");

-- CreateIndex
CREATE INDEX "kana_characters_kana_type_row_idx" ON "kana_characters"("kana_type", "row");

-- CreateIndex
CREATE INDEX "kana_characters_kana_type_category_idx" ON "kana_characters"("kana_type", "category");

-- CreateIndex
CREATE UNIQUE INDEX "kana_characters_kana_type_character_key" ON "kana_characters"("kana_type", "character");

-- CreateIndex
CREATE INDEX "user_kana_progress_user_id_mastered_idx" ON "user_kana_progress"("user_id", "mastered");

-- CreateIndex
CREATE UNIQUE INDEX "user_kana_progress_user_id_kana_id_key" ON "user_kana_progress"("user_id", "kana_id");

-- CreateIndex
CREATE UNIQUE INDEX "kana_learning_stages_kana_type_stage_number_key" ON "kana_learning_stages"("kana_type", "stage_number");

-- CreateIndex
CREATE INDEX "user_kana_stages_user_id_idx" ON "user_kana_stages"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_kana_stages_user_id_stage_id_key" ON "user_kana_stages"("user_id", "stage_id");

-- CreateIndex
CREATE INDEX "user_favorite_characters_user_id_idx" ON "user_favorite_characters"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_favorite_characters_user_id_character_id_key" ON "user_favorite_characters"("user_id", "character_id");

-- CreateIndex
CREATE INDEX "user_character_unlocks_user_id_idx" ON "user_character_unlocks"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_character_unlocks_user_id_character_id_key" ON "user_character_unlocks"("user_id", "character_id");

-- CreateIndex
CREATE INDEX "subscriptions_user_id_idx" ON "subscriptions"("user_id");

-- CreateIndex
CREATE INDEX "subscriptions_status_idx" ON "subscriptions"("status");

-- CreateIndex
CREATE INDEX "subscriptions_current_period_end_idx" ON "subscriptions"("current_period_end");

-- CreateIndex
CREATE UNIQUE INDEX "payments_portone_payment_id_key" ON "payments"("portone_payment_id");

-- CreateIndex
CREATE INDEX "payments_user_id_idx" ON "payments"("user_id");

-- CreateIndex
CREATE INDEX "payments_subscription_id_idx" ON "payments"("subscription_id");

-- CreateIndex
CREATE INDEX "payments_portone_payment_id_idx" ON "payments"("portone_payment_id");

-- CreateIndex
CREATE INDEX "daily_ai_usage_user_id_date_idx" ON "daily_ai_usage"("user_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "daily_ai_usage_user_id_date_key" ON "daily_ai_usage"("user_id", "date");

-- AddForeignKey
ALTER TABLE "quiz_sessions" ADD CONSTRAINT "quiz_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_answers" ADD CONSTRAINT "quiz_answers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "quiz_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "conversation_scenarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_character_id_fkey" FOREIGN KEY ("character_id") REFERENCES "ai_characters"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_achievements" ADD CONSTRAINT "user_achievements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_missions" ADD CONSTRAINT "daily_missions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_progress" ADD CONSTRAINT "daily_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_vocab_progress" ADD CONSTRAINT "user_vocab_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_vocab_progress" ADD CONSTRAINT "user_vocab_progress_vocabulary_id_fkey" FOREIGN KEY ("vocabulary_id") REFERENCES "vocabularies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_grammar_progress" ADD CONSTRAINT "user_grammar_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_grammar_progress" ADD CONSTRAINT "user_grammar_progress_grammar_id_fkey" FOREIGN KEY ("grammar_id") REFERENCES "grammars"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "push_subscriptions" ADD CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wordbook_entries" ADD CONSTRAINT "wordbook_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_kana_progress" ADD CONSTRAINT "user_kana_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_kana_progress" ADD CONSTRAINT "user_kana_progress_kana_id_fkey" FOREIGN KEY ("kana_id") REFERENCES "kana_characters"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_kana_stages" ADD CONSTRAINT "user_kana_stages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_kana_stages" ADD CONSTRAINT "user_kana_stages_stage_id_fkey" FOREIGN KEY ("stage_id") REFERENCES "kana_learning_stages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_favorite_characters" ADD CONSTRAINT "user_favorite_characters_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_favorite_characters" ADD CONSTRAINT "user_favorite_characters_character_id_fkey" FOREIGN KEY ("character_id") REFERENCES "ai_characters"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_character_unlocks" ADD CONSTRAINT "user_character_unlocks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_character_unlocks" ADD CONSTRAINT "user_character_unlocks_character_id_fkey" FOREIGN KEY ("character_id") REFERENCES "ai_characters"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_ai_usage" ADD CONSTRAINT "daily_ai_usage_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

