import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/settings/call_settings.dart';

class CallSettingsSheet extends StatefulWidget {
  final CallSettings settings;

  const CallSettingsSheet({
    super.key,
    required this.settings,
  });

  @override
  State<CallSettingsSheet> createState() => _CallSettingsSheetState();
}

class _CallSettingsSheetState extends State<CallSettingsSheet> {
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
                Icon(LucideIcons.timer,
                    size: 20, color: theme.colorScheme.primary),
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
              label:
                  '${(_current.silenceDurationMs / 1000).toStringAsFixed(1)}초',
              onChanged: (value) {
                setState(() {
                  _current =
                      _current.copyWith(silenceDurationMs: value.round());
                });
              },
            ),
            const SizedBox(height: 8),

            // Show subtitles
            SwitchListTile(
              secondary: Icon(LucideIcons.subtitles,
                  size: 20, color: theme.colorScheme.primary),
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
              secondary: Icon(LucideIcons.barChart3,
                  size: 20, color: theme.colorScheme.primary),
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
                onPressed: () => Navigator.of(context).pop(_current),
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
