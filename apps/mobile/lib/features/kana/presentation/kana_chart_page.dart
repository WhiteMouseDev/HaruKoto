import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/text_theme.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../data/models/kana_character_model.dart';
import '../providers/kana_provider.dart';
import 'widgets/kana_character_card.dart';
import 'widgets/kana_chart_grid.dart';

class KanaChartPage extends ConsumerStatefulWidget {
  const KanaChartPage({super.key});

  @override
  ConsumerState<KanaChartPage> createState() => _KanaChartPageState();
}

class _KanaChartPageState extends ConsumerState<KanaChartPage> {
  static const _types = ['HIRAGANA', 'KATAKANA'];
  static const _labels = ['히라가나', '가타카나'];
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Prefetch both scripts so each detail card can show its counterpart.
    final activeType = _types[_selectedIndex];
    final activeProvider = kanaBasicCharactersProvider(activeType);
    final active = ref.watch(activeProvider);
    ref.watch(kanaBasicCharactersProvider(_types[1 - _selectedIndex]));
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: light ? Colors.white : theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    color: foreground,
                    onPressed: () => context.pop(),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '가나 차트',
                          style: TextStyle(
                            fontFamily: redesignFontFamily,
                            fontSize: 20,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppSegmentedTabs(
                labels: _labels,
                compact: true,
                selectedIndex: _selectedIndex,
                onChanged: (index) => setState(() => _selectedIndex = index),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: active.when(
                loading: () => _chartViewport(
                  activeType,
                  Semantics(
                    label: '${_labels[_selectedIndex]} 표를 불러오는 중',
                    liveRegion: true,
                    excludeSemantics: true,
                    child: KanaChartGrid.loading(
                        katakana: activeType == 'KATAKANA'),
                  ),
                ),
                error: (error, stackTrace) => AppErrorRetry(
                  message: '${_labels[_selectedIndex]}를 불러오지 못했어요.',
                  onRetry: () => ref.invalidate(activeProvider),
                ),
                data: (characters) => characters.isEmpty
                    ? Center(
                        child: Text('표시할 ${_labels[_selectedIndex]}가 없어요.'),
                      )
                    : _chartViewport(
                        activeType,
                        KanaChartGrid(
                          characters: characters,
                          katakana: activeType == 'KATAKANA',
                          onCharacterTap: (character) =>
                              _showCharacterSheet(context, character),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartViewport(String type, Widget child) => SingleChildScrollView(
        key: ValueKey(type),
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: child,
      );

  void _showCharacterSheet(
    BuildContext context,
    KanaCharacterModel character,
  ) {
    final otherType =
        character.kanaType == 'HIRAGANA' ? 'KATAKANA' : 'HIRAGANA';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final other = ref.watch(kanaBasicCharactersProvider(otherType)).value;
          final counterpart = other
              ?.where((kana) => kana.romaji == character.romaji)
              .firstOrNull;
          return SingleChildScrollView(
            child: KanaCharacterCard(
              character: character,
              correspondingCharacter: counterpart,
            ),
          );
        },
      ),
    );
  }
}
