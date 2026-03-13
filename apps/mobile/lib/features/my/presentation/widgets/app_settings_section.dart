import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/providers/quiz_settings_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../data/models/profile_detail_model.dart';

class AppSettingsSection extends ConsumerWidget {
  final bool notificationEnabled;
  final CallSettings callSettings;
  final Future<void> Function(String field, Object value) onUpdate;
  final void Function(CallSettings) onCallSettingsChanged;

  const AppSettingsSection({
    super.key,
    required this.notificationEnabled,
    required this.callSettings,
    required this.onUpdate,
    required this.onCallSettingsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '앱 설정',
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
              // Theme
              ListTile(
                leading: Icon(LucideIcons.palette, size: 20, color: theme.colorScheme.primary),
                title: const Text('테마 선택', style: TextStyle(fontSize: 14)),
                trailing: Text(
                  _themeModeLabel(themeMode),
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                onTap: () => _showThemeSheet(context, ref, themeMode),
              ),
              const Divider(height: 1),

              // Furigana
              SwitchListTile(
                secondary: Icon(LucideIcons.languages, size: 20, color: theme.colorScheme.primary),
                title: const Text('읽기(후리가나) 표시', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '퀴즈에서 한자 위에 히라가나 표시',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                value: ref.watch(quizSettingsProvider).showFurigana,
                onChanged: (value) =>
                    ref.read(quizSettingsProvider.notifier).setShowFurigana(value),
              ),
              const Divider(height: 1),

              // Study Reminder
              SwitchListTile(
                secondary: Icon(LucideIcons.bell, size: 20, color: theme.colorScheme.primary),
                title: const Text('학습 리마인더', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '매일 설정한 시간에 알림',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                value: ref.watch(notificationSettingsProvider).reminderEnabled,
                onChanged: (value) =>
                    ref.read(notificationSettingsProvider.notifier).setReminderEnabled(value),
              ),
              if (ref.watch(notificationSettingsProvider).reminderEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(LucideIcons.clock, size: 20, color: theme.colorScheme.primary),
                  title: const Text('리마인더 시간', style: TextStyle(fontSize: 14)),
                  trailing: Text(
                    ref.watch(notificationSettingsProvider).reminderTimeLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => _showTimePicker(context, ref),
                ),
              ],
              const Divider(height: 1),

              // Streak Defense
              SwitchListTile(
                secondary: Icon(LucideIcons.flame, size: 20, color: theme.colorScheme.primary),
                title: const Text('스트릭 방어 알림', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '오늘 학습 미완료 시 22:00에 알림',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                value: ref.watch(notificationSettingsProvider).streakDefenseEnabled,
                onChanged: (value) =>
                    ref.read(notificationSettingsProvider.notifier).setStreakDefenseEnabled(value),
              ),
              const Divider(height: 1),

              // Call Settings
              ListTile(
                leading: Icon(LucideIcons.phone, size: 20, color: theme.colorScheme.primary),
                title: const Text('통화 설정', style: TextStyle(fontSize: 14)),
                trailing: Icon(LucideIcons.chevronRight, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                onTap: () => _showCallSettingsSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '라이트';
      case ThemeMode.dark:
        return '다크';
      case ThemeMode.system:
        return '시스템';
    }
  }

  void _showTimePicker(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(notificationSettingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked != null) {
      ref.read(notificationSettingsProvider.notifier).setReminderTime(picked.hour, picked.minute);
    }
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref, ThemeMode current) {
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
                    '테마 선택',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                for (final entry in [
                  (ThemeMode.light, '라이트', LucideIcons.sun),
                  (ThemeMode.dark, '다크', LucideIcons.moon),
                  (ThemeMode.system, '시스템', LucideIcons.smartphone),
                ])
                  ListTile(
                    leading: Icon(entry.$3, size: 20),
                    title: Text(entry.$2),
                    trailing: current == entry.$1
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(themeProvider.notifier).setThemeMode(entry.$1);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCallSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _CallSettingsSheet(
          settings: callSettings,
          onChanged: (updated) {
            onCallSettingsChanged(updated);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _CallSettingsSheet extends StatefulWidget {
  final CallSettings settings;
  final void Function(CallSettings) onChanged;

  const _CallSettingsSheet({
    required this.settings,
    required this.onChanged,
  });

  @override
  State<_CallSettingsSheet> createState() => _CallSettingsSheetState();
}

class _CallSettingsSheetState extends State<_CallSettingsSheet> {
  late CallSettings _current;

  @override
  void initState() {
    super.initState();
    _current = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '통화 설정',
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Silence timeout slider
            Row(
              children: [
                Icon(LucideIcons.timer, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('침묵 대기 시간', style: TextStyle(fontSize: 14)),
                ),
                Text(
                  '${(_current.silenceDurationMs / 1000).toStringAsFixed(1)}초',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _current.silenceDurationMs.toDouble(),
              min: 0,
              max: 5000,
              divisions: 50,
              label: '${(_current.silenceDurationMs / 1000).toStringAsFixed(1)}초',
              onChanged: (value) {
                setState(() {
                  _current = _current.copyWith(silenceDurationMs: value.round());
                });
              },
            ),
            const SizedBox(height: 8),

            // Show subtitles
            SwitchListTile(
              secondary: Icon(LucideIcons.subtitles, size: 20, color: theme.colorScheme.primary),
              title: const Text('자막 표시', style: TextStyle(fontSize: 14)),
              value: _current.subtitleEnabled,
              onChanged: (value) {
                setState(() {
                  _current = _current.copyWith(subtitleEnabled: value);
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Auto analyze
            SwitchListTile(
              secondary: Icon(LucideIcons.barChart3, size: 20, color: theme.colorScheme.primary),
              title: const Text('통화 후 자동 분석', style: TextStyle(fontSize: 14)),
              value: _current.autoAnalysis,
              onChanged: (value) {
                setState(() {
                  _current = _current.copyWith(autoAnalysis: value);
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => widget.onChanged(_current),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
