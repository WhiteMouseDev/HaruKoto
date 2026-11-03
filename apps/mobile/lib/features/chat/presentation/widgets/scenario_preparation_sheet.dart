import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/sizes.dart';
import '../../data/models/scenario_model.dart';
import '../chat_entry_mode.dart';

/// Returns the chosen input mode; the parent starts the conversation afterward.
class ScenarioPreparationSheet extends StatelessWidget {
  const ScenarioPreparationSheet({super.key, required this.scenario});

  final ScenarioModel scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(scenario.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSizes.sm),
            Text('예상 ${scenario.estimatedMinutes}분 · 상황에 맞게 이야기해 보세요'),
            if (scenario.situation.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text(scenario.situation),
            ],
            if (scenario.yourRole.isNotEmpty || scenario.aiRole.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Text('나의 역할: ${scenario.yourRole}\n상대 역할: ${scenario.aiRole}'),
            ],
            if (scenario.keyExpressions.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text('시작 전에 볼 표현', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.sm),
              ...scenario.keyExpressions.take(3).map(
                    (expression) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: Text(expression),
                    ),
                  ),
            ],
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(ChatEntryMode.voice),
                icon: const Icon(LucideIcons.mic),
                label: const Text('말하기로 연습'),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(ChatEntryMode.text),
                icon: const Icon(LucideIcons.messageSquare),
                label: const Text('글로 연습'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
