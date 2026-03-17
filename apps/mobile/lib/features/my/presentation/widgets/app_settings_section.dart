import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/providers/quiz_settings_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/sound_service.dart';

class AppSettingsSection extends ConsumerWidget {
  final bool showFurigana;
  final Future<void> Function(String field, Object value) onUpdate;

  const AppSettingsSection({
    super.key,
    required this.showFurigana,
    required this.onUpdate,
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
                leading: Icon(LucideIcons.palette,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('테마 선택', style: TextStyle(fontSize: 14)),
                trailing: Text(
                  _themeModeLabel(themeMode),
                  style: TextStyle(
                      fontSize: 14,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                onTap: () => _showThemeSheet(context, ref, themeMode),
              ),
              const Divider(height: 1),

              // Furigana
              SwitchListTile(
                secondary: Icon(LucideIcons.languages,
                    size: 20, color: theme.colorScheme.primary),
                title:
                    const Text('읽기(후리가나) 표시', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '퀴즈에서 한자 위에 히라가나 표시',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                value: ref.watch(quizSettingsProvider).showFurigana,
                onChanged: (value) {
                  ref
                      .read(quizSettingsProvider.notifier)
                      .setShowFurigana(value);
                  onUpdate('app_settings', {'showFurigana': value});
                },
              ),
              const Divider(height: 1),

              // Sound Effects
              _SoundToggle(theme: theme),
              const Divider(height: 1),

              // Haptic Feedback
              _HapticToggle(theme: theme),
              const Divider(height: 1),

              // Study Reminder
              SwitchListTile(
                secondary: Icon(LucideIcons.bell,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('학습 리마인더', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '매일 설정한 시간에 알림',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                value: ref.watch(notificationSettingsProvider).reminderEnabled,
                onChanged: (value) => ref
                    .read(notificationSettingsProvider.notifier)
                    .setReminderEnabled(value),
              ),
              if (ref.watch(notificationSettingsProvider).reminderEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(LucideIcons.clock,
                      size: 20, color: theme.colorScheme.primary),
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
                secondary: Icon(LucideIcons.flame,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('스트릭 방어 알림', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '오늘 학습 미완료 시 22:00에 알림',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                value: ref
                    .watch(notificationSettingsProvider)
                    .streakDefenseEnabled,
                onChanged: (value) => ref
                    .read(notificationSettingsProvider.notifier)
                    .setStreakDefenseEnabled(value),
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
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked != null) {
      unawaited(ref
          .read(notificationSettingsProvider.notifier)
          .setReminderTime(picked.hour, picked.minute));
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
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
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
}

class _SoundToggle extends StatefulWidget {
  final ThemeData theme;
  const _SoundToggle({required this.theme});

  @override
  State<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<_SoundToggle> {
  bool _enabled = SoundService().enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(LucideIcons.volume2,
          size: 20, color: widget.theme.colorScheme.primary),
      title: const Text('효과음', style: TextStyle(fontSize: 14)),
      subtitle: Text(
        '정답/오답 시 효과음 재생',
        style: TextStyle(
            fontSize: 12,
            color:
                widget.theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      value: _enabled,
      onChanged: (value) {
        SoundService().setEnabled(value);
        setState(() => _enabled = value);
      },
    );
  }
}

class _HapticToggle extends StatefulWidget {
  final ThemeData theme;
  const _HapticToggle({required this.theme});

  @override
  State<_HapticToggle> createState() => _HapticToggleState();
}

class _HapticToggleState extends State<_HapticToggle> {
  bool _enabled = HapticService().enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(LucideIcons.vibrate,
          size: 20, color: widget.theme.colorScheme.primary),
      title: const Text('진동 피드백', style: TextStyle(fontSize: 14)),
      subtitle: Text(
        '터치 시 진동으로 반응',
        style: TextStyle(
            fontSize: 12,
            color:
                widget.theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      value: _enabled,
      onChanged: (value) {
        HapticService().setEnabled(value);
        setState(() => _enabled = value);
      },
    );
  }
}
