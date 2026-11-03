import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/scenario_model.dart';
import '../../providers/chat_provider.dart';
import '../chat_entry_mode.dart';
import '../voice_call_launch.dart';
import 'scenario_card.dart';
import 'chat_loading_overlay.dart';
import 'scenario_preparation_sheet.dart';

class ScenarioListView extends ConsumerWidget {
  final String category;
  final ChatEntryMode entryMode;
  final bool starting;
  final String? errorMessage;
  final VoidCallback onBack;
  final ValueChanged<ScenarioModel> onStartConversation;

  const ScenarioListView({
    super.key,
    required this.category,
    required this.entryMode,
    required this.starting,
    this.errorMessage,
    required this.onBack,
    required this.onStartConversation,
  });

  Future<void> _prepare(BuildContext context, ScenarioModel scenario) async {
    final mode = await showModalBottomSheet<ChatEntryMode>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => ScenarioPreparationSheet(scenario: scenario),
    );
    if (!context.mounted || mode == null) return;
    if (mode == ChatEntryMode.voice) {
      openVoiceCallPage(context, scenarioId: scenario.id, scenario: scenario);
    } else {
      onStartConversation(scenario);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryMeta = _getCategoryMeta(category);
    final scenariosAsync = ref.watch(scenariosProvider(category));

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(LucideIcons.arrowLeft),
                      ),
                      Icon(categoryMeta.icon,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        categoryMeta.label,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Text(errorMessage!,
                        style: TextStyle(color: colorScheme.error)),
                  ),
                Expanded(
                  child: scenariosAsync.when(
                    loading: () => ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSizes.md),
                      itemCount: 3,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '시나리오를 불러올 수 없습니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.invalidate(scenariosProvider(category)),
                            icon: const Icon(LucideIcons.refreshCw, size: 14),
                            label: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                    data: (scenarios) {
                      if (scenarios.isEmpty) {
                        return Center(
                          child: Text(
                            '아직 시나리오가 없습니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSizes.md),
                        itemCount: scenarios.length,
                        itemBuilder: (_, index) {
                          final scenario = scenarios[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSizes.sm),
                            child: ScenarioCard(
                              scenario: scenario,
                              onSelect: () => _prepare(context, scenario),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            if (starting) const ChatLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  static _CategoryMeta _getCategoryMeta(String category) {
    switch (category) {
      case 'TRAVEL':
        return const _CategoryMeta(LucideIcons.plane, '여행 시나리오');
      case 'DAILY':
        return const _CategoryMeta(LucideIcons.store, '일상 시나리오');
      case 'BUSINESS':
        return const _CategoryMeta(LucideIcons.briefcase, '비즈니스 시나리오');
      case 'FREE':
        return const _CategoryMeta(LucideIcons.messageSquare, '자유주제 시나리오');
      default:
        return _CategoryMeta(LucideIcons.messageSquare, category);
    }
  }
}

class _CategoryMeta {
  final IconData icon;
  final String label;
  const _CategoryMeta(this.icon, this.label);
}
