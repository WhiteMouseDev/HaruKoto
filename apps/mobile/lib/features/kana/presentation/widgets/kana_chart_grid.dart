import 'package:flutter/material.dart';
import '../../data/models/kana_character_model.dart';

class KanaChartGrid extends StatelessWidget {
  final List<KanaCharacterModel> characters;
  final void Function(KanaCharacterModel) onCharacterTap;

  const KanaChartGrid({
    super.key,
    required this.characters,
    required this.onCharacterTap,
  });

  static const _rows = [
    _RowDef(key: 'a', label: '\u2205'),
    _RowDef(key: 'ka', label: 'k'),
    _RowDef(key: 'sa', label: 's'),
    _RowDef(key: 'ta', label: 't'),
    _RowDef(key: 'na', label: 'n'),
    _RowDef(key: 'ha', label: 'h'),
    _RowDef(key: 'ma', label: 'm'),
    _RowDef(key: 'ya', label: 'y'),
    _RowDef(key: 'ra', label: 'r'),
    _RowDef(key: 'wa', label: 'w'),
    _RowDef(key: 'n', label: 'n'),
  ];

  static const _columns = ['a', 'i', 'u', 'e', 'o'];

  static final _emptyCells = {
    'ya-i',
    'ya-e',
    'wa-i',
    'wa-u',
    'wa-e',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charMap = <String, KanaCharacterModel>{};
    for (final c in characters) {
      charMap['${c.row}-${c.column}'] = c;
    }

    return Column(
      children: [
        // Column headers
        Row(
          children: [
            const SizedBox(width: 28),
            ..._columns.map((col) {
              return Expanded(
                child: Center(
                  child: Text(
                    col,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 6),

        // Rows
        ..._rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Row header
                SizedBox(
                  width: 28,
                  height: 44,
                  child: Center(
                    child: Text(
                      row.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                // Cells
                ..._columns.map((col) {
                  final cellKey = '${row.key}-$col';

                  // n row: only show 'a' column
                  if (row.key == 'n' && col != 'a') {
                    return const Expanded(child: SizedBox(height: 44));
                  }

                  if (_emptyCells.contains(cellKey)) {
                    return const Expanded(child: SizedBox(height: 44));
                  }

                  final character = charMap[cellKey];
                  if (character == null) {
                    return const Expanded(child: SizedBox(height: 44));
                  }

                  final status = _getCellStatus(character);

                  Color bgColor;
                  Color textColor;
                  double opacity = 1.0;

                  switch (status) {
                    case _CellStatus.mastered:
                      bgColor =
                          theme.colorScheme.primary.withValues(alpha: 0.2);
                      textColor = theme.colorScheme.primary;
                    case _CellStatus.learned:
                      bgColor = theme.colorScheme.surfaceContainerHigh;
                      textColor = theme.colorScheme.onSurface;
                    case _CellStatus.locked:
                      bgColor = theme.colorScheme.surfaceContainerHigh;
                      textColor = theme.colorScheme.onSurface
                          .withValues(alpha: 0.5);
                      opacity = 0.4;
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity,
                        child: Material(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onCharacterTap(character),
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: Text(
                                  character.character,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  _CellStatus _getCellStatus(KanaCharacterModel character) {
    if (character.progress?.mastered == true) return _CellStatus.mastered;
    if (character.progress != null) return _CellStatus.learned;
    return _CellStatus.locked;
  }
}

class _RowDef {
  final String key;
  final String label;

  const _RowDef({required this.key, required this.label});
}

enum _CellStatus { mastered, learned, locked }
