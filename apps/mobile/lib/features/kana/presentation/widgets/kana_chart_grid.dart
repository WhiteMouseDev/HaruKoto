import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../data/models/kana_character_model.dart';

class KanaChartGrid extends StatelessWidget {
  const KanaChartGrid({
    super.key,
    required this.characters,
    required this.katakana,
    required ValueChanged<KanaCharacterModel> onCharacterTap,
  }) : _onCharacterTap = onCharacterTap;

  const KanaChartGrid.loading({super.key, required this.katakana})
      : characters = const [],
        _onCharacterTap = null;

  final List<KanaCharacterModel> characters;
  final bool katakana;
  final ValueChanged<KanaCharacterModel>? _onCharacterTap;

  static const _rows = [
    ('a', 'あ', 'ア', '아'),
    ('ka', 'か', 'カ', '카'),
    ('sa', 'さ', 'サ', '사'),
    ('ta', 'た', 'タ', '타'),
    ('na', 'な', 'ナ', '나'),
    ('ha', 'は', 'ハ', '하'),
    ('ma', 'ま', 'マ', '마'),
    ('ya', 'や', 'ヤ', '야'),
    ('ra', 'ら', 'ラ', '라'),
    ('wa', 'わ', 'ワ', '와'),
  ];
  static const _columns = [
    ('a', 'あ', 'ア', '아'),
    ('i', 'い', 'イ', '이'),
    ('u', 'う', 'ウ', '우'),
    ('e', 'え', 'エ', '에'),
    ('o', 'お', 'オ', '오'),
  ];
  static const _emptyCells = {
    ('ya', 'i'),
    ('ya', 'e'),
    ('wa', 'i'),
    ('wa', 'u'),
    ('wa', 'e'),
  };
  static const _axisFontSize = 12.0;
  static const _kanaFontSize = 16.0;
  static const _gap = 8.0;
  static const _blockCorners = BorderRadius.all(Radius.circular(4));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final onCharacterTap = _onCharacterTap;
    final loading = onCharacterTap == null;
    const placeholder = AppSkeletonBlock(radius: 4);
    final scaler = MediaQuery.textScalerOf(context);
    final cells = {
      for (final character in characters)
        (character.row, character.column): character,
    };
    final scaleAxis = scaler.scale(_axisFontSize);
    final minSlotWidth =
        max(scaleAxis * 2 + 10, scaler.scale(_kanaFontSize) + 12);
    final headerHeight = max(28.0, scaleAxis * 1.4 + 8);
    final rowHeight = max(36.0, scaler.scale(_kanaFontSize) * 1.4 + 8);
    final nasal = cells[('n', 'a')];

    return LayoutBuilder(builder: (context, constraints) {
      final slotCount = _columns.length + 1;
      final gapsWidth = _gap * (slotCount - 1);
      final width =
          max(constraints.maxWidth, minSlotWidth * slotCount + gapsWidth);
      final slotWidth = (width - gapsWidth) / slotCount;
      final chart = SizedBox(
        width: width,
        child: Column(
          children: [
            _KanaChartRow(
              height: headerHeight,
              cells: [
                const SizedBox.shrink(),
                for (final (_, hiragana, katakanaGlyph, korean) in _columns)
                  loading
                      ? placeholder
                      : _KanaAxisCell(
                          kana: katakana ? katakanaGlyph : hiragana,
                          reading: korean,
                          color: AppColors.redesignVocabulary
                              .withValues(alpha: 0.32),
                          foreground: foreground,
                        ),
              ],
            ),
            for (final (row, hiragana, katakanaGlyph, korean) in _rows) ...[
              const SizedBox(height: _gap),
              _KanaChartRow(
                height: rowHeight,
                cells: [
                  if (loading)
                    placeholder
                  else
                    _KanaAxisCell(
                      kana: katakana ? katakanaGlyph : hiragana,
                      reading: korean,
                      color: AppColors.redesignGrammar.withValues(alpha: 0.24),
                      foreground: foreground,
                    ),
                  for (final (column, _, _, _) in _columns)
                    if (_emptyCells.contains((row, column)))
                      const SizedBox.shrink()
                    else if (onCharacterTap == null)
                      placeholder
                    else if (cells[(row, column)] case final character?)
                      _KanaCell(
                        character: character,
                        onTap: onCharacterTap,
                      )
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ],
            // The syllabic nasal occupies its own row and has no vowel column.
            const SizedBox(height: _gap),
            SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: slotWidth + _gap),
                  if (onCharacterTap == null)
                    const Expanded(child: placeholder)
                  else if (nasal != null)
                    Expanded(
                      child: _KanaCell(
                        character: nasal,
                        onTap: onCharacterTap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
      if (width <= constraints.maxWidth) return chart;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        child: chart,
      );
    });
  }
}

class _KanaChartRow extends StatelessWidget {
  const _KanaChartRow({required this.height, required this.cells});

  final double height;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cells.length; index++) ...[
            if (index > 0) const SizedBox(width: KanaChartGrid._gap),
            Expanded(child: cells[index]),
          ],
        ],
      ),
    );
  }
}

class _KanaAxisCell extends StatelessWidget {
  const _KanaAxisCell({
    required this.kana,
    required this.reading,
    required this.color,
    required this.foreground,
  });

  final String kana;
  final String reading;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: KanaChartGrid._axisFontSize,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: foreground,
    );
    return Semantics(
      header: true,
      label: '$kana, $reading',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: KanaChartGrid._blockCorners,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kana, style: style, locale: const Locale('ja')),
              const SizedBox(width: 2),
              Text(reading, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanaCell extends StatelessWidget {
  const _KanaCell({required this.character, required this.onTap});

  final KanaCharacterModel character;
  final ValueChanged<KanaCharacterModel> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final progress = character.progress;
    final (fill, status) = switch (progress) {
      KanaCharacterProgress(mastered: true) => (
          colors.primary.withValues(alpha: 0.32),
          '마스터',
        ),
      KanaCharacterProgress() => (
          colors.primary.withValues(alpha: 0.12),
          '학습 중',
        ),
      null => (
          light ? AppColors.redesignControl : colors.surfaceContainerHigh,
          '미학습',
        ),
    };
    final reading = character.row == 'n' ? '받침 소리' : character.pronunciation;

    void openDetail() => onTap(character);

    return Semantics(
      label: '${character.character}, $reading, $status, 문자 상세',
      button: true,
      excludeSemantics: true,
      onTap: openDetail,
      child: Material(
        color: fill,
        borderRadius: KanaChartGrid._blockCorners,
        child: InkWell(
          borderRadius: KanaChartGrid._blockCorners,
          onTap: openDetail,
          child: Center(
            child: Text(
              character.character,
              locale: const Locale('ja'),
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: KanaChartGrid._kanaFontSize,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
