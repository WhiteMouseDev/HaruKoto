import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../data/models/quiz_session_model.dart';
import '../data/models/smart_preview_model.dart';
import 'quiz_launch.dart';
import 'widgets/today_study_sheet.dart';

enum StudyEntryActionKind {
  resumeOrNew,
  showPreview,
  startQuiz,
}

class StudyEntryDecision {
  const StudyEntryDecision({
    required this.action,
    this.mode,
  });

  final StudyEntryActionKind action;
  final String? mode;

  bool get isTappable => true;
}

bool categorySupportsSmartStudy(String category) {
  return category == 'VOCABULARY' || category == 'GRAMMAR';
}

String? defaultQuizModeForCategory(String category) {
  if (category == 'SENTENCE_ARRANGE') {
    return 'arrange';
  }
  return null;
}

/// 진입 전략. unavailable 상태 없음 — 항상 시작 가능한 경로 보장.
///
/// 우선순위: resume > smart preview > 기본 퀴즈
StudyEntryDecision resolveStudyEntryDecision({
  required String category,
  bool hasIncomplete = false,
  bool hasPreview = false,
}) {
  // Smart 카테고리 (VOCABULARY, GRAMMAR)
  if (categorySupportsSmartStudy(category)) {
    // 1순위: 미완료 세션 이어하기
    if (hasIncomplete) {
      return const StudyEntryDecision(
        action: StudyEntryActionKind.resumeOrNew,
      );
    }
    // 2순위: Smart Preview 있으면 오늘의 학습
    if (hasPreview) {
      return const StudyEntryDecision(
        action: StudyEntryActionKind.showPreview,
      );
    }
    // 3순위: 콘텐츠 있으면 기본 퀴즈 시작 (Day 1 유저 포함)
    return const StudyEntryDecision(
      action: StudyEntryActionKind.startQuiz,
    );
  }

  // 비-Smart 카테고리 (SENTENCE_ARRANGE 등)
  return StudyEntryDecision(
    action: StudyEntryActionKind.startQuiz,
    mode: defaultQuizModeForCategory(category),
  );
}

Future<void> showTodayStudySheetModal(
  BuildContext context, {
  required SmartPreviewModel preview,
  required String jlptLevel,
  required String category,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => TodayStudySheet(
      data: preview,
      jlptLevel: jlptLevel,
      category: category,
    ),
  );
}

Future<void> showResumeOrNewStudySheet(
  BuildContext context, {
  required IncompleteSessionModel session,
  required String selectedCategory,
  required String jlptLevel,
  SmartPreviewModel? preview,
}) {
  final theme = Theme.of(context);

  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '진행 중인 학습이 있어요',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${session.jlptLevel} ${session.quizType == 'VOCABULARY' ? '단어' : '문법'} · ${session.answeredCount}/${session.totalQuestions} 문제 진행',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.lightSubtext,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openQuizPageForSession(
                      context,
                      quizType: session.quizType,
                      jlptLevel: session.jlptLevel,
                      count: session.totalQuestions,
                      resumeSessionId: session.id,
                    );
                  },
                  icon: const Icon(LucideIcons.playCircle, size: 18),
                  label: const Text(
                    '이어서 학습하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: preview == null
                      ? () {
                          // Smart Preview 없어도 기본 퀴즈로 시작 가능
                          Navigator.pop(ctx);
                          openQuizPageForSession(
                            context,
                            quizType: selectedCategory,
                            jlptLevel: jlptLevel,
                            count: 10,
                          );
                        }
                      : () {
                          Navigator.pop(ctx);
                          showTodayStudySheetModal(
                            context,
                            preview: preview,
                            jlptLevel: jlptLevel,
                            category: selectedCategory,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    preview == null ? '새로 시작하기' : '오늘의 학습 보기',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> executeStudyEntryDecision(
  BuildContext context, {
  required StudyEntryDecision decision,
  required String category,
  required String jlptLevel,
  SmartPreviewModel? preview,
  IncompleteSessionModel? incomplete,
}) {
  switch (decision.action) {
    case StudyEntryActionKind.resumeOrNew:
      if (incomplete == null) return Future.value();
      return showResumeOrNewStudySheet(
        context,
        session: incomplete,
        selectedCategory: category,
        jlptLevel: jlptLevel,
        preview: preview,
      );
    case StudyEntryActionKind.showPreview:
      if (preview == null) return Future.value();
      return showTodayStudySheetModal(
        context,
        preview: preview,
        jlptLevel: jlptLevel,
        category: category,
      );
    case StudyEntryActionKind.startQuiz:
      openQuizPageForSession(
        context,
        quizType: category,
        jlptLevel: jlptLevel,
        count: 10,
        mode: decision.mode,
      );
      return Future.value();
  }
}
