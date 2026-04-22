import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../data/models/stage_model.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';
import '../study_page.dart';
import 'study_stage_card.dart';
import 'study_stage_empty_state.dart';
import 'study_stage_list_skeleton.dart';
import 'study_stage_mode_sheet.dart';

/// Content for each study category tab (vocabulary, grammar, sentence arrange).
/// Shows a vertical list of stage cards fetched from the API.
class StudyTabContent extends ConsumerWidget {
  final StudyCategory category;
  final String jlptLevel;

  const StudyTabContent({
    super.key,
    required this.category,
    required this.jlptLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagesAsync = ref.watch(
      stagesProvider((category: category.apiType, jlptLevel: jlptLevel)),
    );

    return stagesAsync.when(
      loading: () => const StudyStageListSkeleton(),
      error: (error, _) => AppErrorRetry(
        onRetry: () => ref.invalidate(
          stagesProvider((category: category.apiType, jlptLevel: jlptLevel)),
        ),
      ),
      data: (stages) {
        if (stages.isEmpty) {
          return const StudyStageEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: stages.length,
          itemBuilder: (context, index) {
            final stage = stages[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StudyStageCard(
                stage: stage,
                onTap: () {
                  _openStage(context, ref, stage);
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openStage(
    BuildContext context,
    WidgetRef ref,
    StageModel stage,
  ) async {
    final mode = await showStudyStageModeSheet(
      context: context,
      stage: stage,
      category: category,
    );
    if (!context.mounted || mode == null) return;

    return openQuizPageForSession(
      context,
      quizType: category.apiType,
      jlptLevel: jlptLevel,
      count: stage.contentCount > 0 ? stage.contentCount : 10,
      mode: mode != 'normal' ? mode : null,
      stageId: stage.id,
    ).then((_) {
      ref.invalidate(
        stagesProvider((category: category.apiType, jlptLevel: jlptLevel)),
      );
    });
  }
}
