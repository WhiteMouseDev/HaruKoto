import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/study_provider.dart';
import '../quiz_page.dart';
import 'jlpt_level_selector.dart';
import 'quiz_mode_selector.dart';
import 'quiz_type_selector.dart';

/// Bottom sheet for "자유 퀴즈" — level, type, mode selection + start.
class FreeQuizSheet extends ConsumerStatefulWidget {
  const FreeQuizSheet({super.key});

  @override
  ConsumerState<FreeQuizSheet> createState() => _FreeQuizSheetState();
}

class _FreeQuizSheetState extends ConsumerState<FreeQuizSheet> {
  String _level = 'N5';
  String _type = 'VOCABULARY';
  String _mode = 'normal';

  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  static const _quizTypes = [
    ('VOCABULARY', '단어'),
    ('GRAMMAR', '문법'),
  ];

  static const _modeLabels = {
    'normal': '4지선다',
    'matching': '매칭',
    'cloze': '빈칸',
    'arrange': '어순',
  };

  List<String> get _availableModes {
    if (_type == 'GRAMMAR') {
      // Grammar doesn't support matching
      return ['normal', 'cloze', 'arrange'];
    }
    return ['normal', 'matching', 'cloze', 'arrange'];
  }

  void _startQuiz() {
    Navigator.pop(context);
    Navigator.of(context, rootNavigator: true).push(
      quizRoute(QuizPage(
        quizType: _type,
        jlptLevel: _level,
        count: 10,
        mode: _mode != 'normal' ? _mode : null,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(
      quizStatsProvider((level: _level, type: _type)),
    );
    final stats = statsAsync.hasValue ? statsAsync.value : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '자유 퀴즈',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // JLPT Level
            JlptLevelSelector(
              levels: _jlptLevels,
              selected: _level,
              onChanged: (level) {
                setState(() {
                  _level = level;
                });
              },
            ),
            const SizedBox(height: 16),

            // Quiz Type (단어 / 문법)
            QuizTypeSelector(
              quizTypes: _quizTypes,
              selectedType: _type,
              onTypeChanged: (type) {
                setState(() {
                  _type = type;
                  // Reset mode if current mode is not available
                  if (!_availableModes.contains(_mode)) {
                    _mode = 'normal';
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Quiz Mode
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '퀴즈 유형',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            QuizModeSelector(
              selectedMode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
              availableModes: _availableModes,
            ),
            const SizedBox(height: 20),

            // Stats row
            if (stats != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_level ${_type == 'VOCABULARY' ? '단어' : '문법'} · ${stats.totalCount}개',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '진행률 ${stats.progress}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _startQuiz,
                icon: Icon(LucideIcons.play, size: 18,
                    color: theme.colorScheme.onPrimary),
                label: Text(
                  '${_modeLabels[_mode] ?? '4지선다'} 학습 시작 (10문제)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
