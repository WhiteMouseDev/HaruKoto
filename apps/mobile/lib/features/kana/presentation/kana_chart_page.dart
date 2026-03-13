import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../data/models/kana_character_model.dart';
import '../providers/kana_provider.dart';
import 'widgets/kana_chart_grid.dart';
import 'widgets/kana_character_card.dart';

class KanaChartPage extends ConsumerStatefulWidget {
  const KanaChartPage({super.key});

  @override
  ConsumerState<KanaChartPage> createState() => _KanaChartPageState();
}

class _KanaChartPageState extends ConsumerState<KanaChartPage> {
  String _selectedType = 'HIRAGANA';


  @override
  Widget build(BuildContext context) {
    final hiraganaAsync = ref.watch(kanaBasicCharactersProvider('HIRAGANA'));
    final katakanaAsync = ref.watch(kanaBasicCharactersProvider('KATAKANA'));
    final theme = Theme.of(context);

    // Multi-provider composition: manual handling since loading state
    // combines two independent kana providers.
    final isLoading = hiraganaAsync.isLoading || katakanaAsync.isLoading;
    final activeData = _selectedType == 'HIRAGANA'
        ? hiraganaAsync.value
        : katakanaAsync.value;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: () => context.pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '50음도',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),

              // Tab switcher
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _tabButton(context, '히라가나', 'HIRAGANA'),
                    _tabButton(context, '가타카나', 'KATAKANA'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // Chart
              Expanded(
                child: isLoading
                    ? const AppSkeleton(
                        itemCount: 11,
                        itemHeights: [48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48],
                      )
                    : SingleChildScrollView(
                        child: KanaChartGrid(
                          characters: activeData ?? [],
                          onCharacterTap: (char) {
                            _showCharacterSheet(context, char,
                                hiraganaAsync.value, katakanaAsync.value);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, String label, String type) {
    final theme = Theme.of(context);
    final isSelected = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.overlay(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCharacterSheet(
    BuildContext context,
    KanaCharacterModel character,
    List<KanaCharacterModel>? hiraganaChars,
    List<KanaCharacterModel>? katakanaChars,
  ) {
    final otherChars =
        character.kanaType == 'HIRAGANA' ? katakanaChars : hiraganaChars;
    final corresponding =
        otherChars?.where((c) => c.romaji == character.romaji).firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => KanaCharacterCard(
        character: character,
        correspondingCharacter: corresponding,
      ),
    );
  }
}

