import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';

class SettingsMenu extends StatelessWidget {
  final String jlptLevel;
  final bool showKana;
  final Future<void> Function(String field, Object value) onUpdate;

  const SettingsMenu({
    super.key,
    required this.jlptLevel,
    required this.showKana,
    required this.onUpdate,
  });

  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Study Settings
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '학습 설정',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // JLPT Level
              ListTile(
                leading: Icon(LucideIcons.graduationCap,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('JLPT 레벨', style: TextStyle(fontSize: 14)),
                trailing: DropdownButton<String>(
                  value: jlptLevel,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                      fontSize: 14, color: theme.colorScheme.onSurface),
                  items: _jlptLevels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onUpdate('jlptLevel', value);
                  },
                ),
              ),
              const Divider(height: 1),

              // Show Kana
              SwitchListTile(
                secondary: Icon(LucideIcons.languages,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('가나 학습 표시', style: TextStyle(fontSize: 14)),
                value: showKana,
                onChanged: (value) => onUpdate('showKana', value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
