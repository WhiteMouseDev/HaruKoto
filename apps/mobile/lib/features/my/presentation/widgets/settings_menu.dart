import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';

class SettingsMenu extends StatefulWidget {
  final String jlptLevel;
  final bool showKana;
  final Future<void> Function(String field, Object value) onUpdate;

  const SettingsMenu({
    super.key,
    required this.jlptLevel,
    required this.showKana,
    required this.onUpdate,
  });

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  late String _jlptLevel;
  late bool _showKana;

  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  void initState() {
    super.initState();
    _jlptLevel = widget.jlptLevel;
    _showKana = widget.showKana;
  }

  @override
  void didUpdateWidget(SettingsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from server if parent provides new values
    if (oldWidget.jlptLevel != widget.jlptLevel) {
      _jlptLevel = widget.jlptLevel;
    }
    if (oldWidget.showKana != widget.showKana) {
      _showKana = widget.showKana;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                trailing: Text(
                  _jlptLevel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                onTap: () => _showJlptSheet(context),
              ),
              const Divider(height: 1),

              // Show Kana
              SwitchListTile(
                secondary: Icon(LucideIcons.languages,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('가나 학습 표시', style: TextStyle(fontSize: 14)),
                value: _showKana,
                onChanged: (value) {
                  HapticService().selection();
                  setState(() => _showKana = value);
                  widget.onUpdate('showKana', value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showJlptSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'JLPT 레벨 선택',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final level in _jlptLevels)
                  ListTile(
                    title: Text(level),
                    trailing: _jlptLevel == level
                        ? Icon(LucideIcons.check,
                            color: theme.colorScheme.primary, size: 20)
                        : null,
                    selected: _jlptLevel == level,
                    selectedTileColor:
                        theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      HapticService().selection();
                      Navigator.pop(context);
                      if (level != _jlptLevel) {
                        // Optimistic: update local state immediately
                        setState(() => _jlptLevel = level);
                        // Server sync in background
                        widget.onUpdate('jlptLevel', level);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
