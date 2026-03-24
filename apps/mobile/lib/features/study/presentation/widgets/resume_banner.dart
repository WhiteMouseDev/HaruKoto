import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/quiz_session_model.dart';
import '../quiz_launch.dart';

class ResumeBanner extends StatelessWidget {
  final IncompleteSessionModel session;

  const ResumeBanner({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning(theme.brightness).withValues(alpha: 0.1),
        border: Border.all(
            color: AppColors.warning(theme.brightness).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning(theme.brightness)
                      .withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.pencil,
                    size: 20, color: AppColors.warning(theme.brightness)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '진행 중인 퀴즈가 있어요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${s.jlptLevel} ${s.quizType == 'VOCABULARY' ? '단어' : '문법'} · ${s.answeredCount}/${s.totalQuestions} 문제',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    openQuizPageForSession(
                      context,
                      quizType: s.quizType,
                      jlptLevel: s.jlptLevel,
                      count: s.totalQuestions,
                    );
                  },
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('새로 시작'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    openQuizPageForSession(
                      context,
                      quizType: s.quizType,
                      jlptLevel: s.jlptLevel,
                      count: s.totalQuestions,
                      resumeSessionId: s.id,
                    );
                  },
                  icon: const Icon(LucideIcons.playCircle, size: 14),
                  label: const Text('이어서 풀기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
