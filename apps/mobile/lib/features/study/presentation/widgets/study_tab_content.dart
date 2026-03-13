import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../providers/study_provider.dart';
import '../study_page.dart';
import 'quiz_mode_selector.dart';
import 'my_study_data.dart';

/// Content for each study category tab (vocabulary, grammar, sentence arrange).
/// Shows quiz stats, mode selector (where applicable), and start button.
class StudyTabContent extends ConsumerStatefulWidget {
  final StudyCategory category;
  final String jlptLevel;
  final ValueChanged<String> onStartQuiz;

  const StudyTabContent({
    super.key,
    required this.category,
    required this.jlptLevel,
    required this.onStartQuiz,
  });

  @override
  ConsumerState<StudyTabContent> createState() => _StudyTabContentState();
}

class _StudyTabContentState extends ConsumerState<StudyTabContent> {
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = _defaultMode;
  }

  String get _defaultMode {
    switch (widget.category) {
      case StudyCategory.sentenceArrange:
        return 'arrange';
      case StudyCategory.vocabulary:
      case StudyCategory.grammar:
        return 'normal';
      case StudyCategory.kana:
        return 'normal';
    }
  }

  /// Which modes are available for this category (task 1-11).
  List<String> get _availableModes {
    switch (widget.category) {
      case StudyCategory.vocabulary:
        return ['normal', 'matching', 'cloze'];
      case StudyCategory.grammar:
        return ['normal', 'cloze'];
      case StudyCategory.sentenceArrange:
        return []; // No mode selector; always arrange
      case StudyCategory.kana:
        return [];
    }
  }

  bool get _showModeSelector => _availableModes.isNotEmpty;

  String get _categoryLabel {
    switch (widget.category) {
      case StudyCategory.vocabulary:
        return '단어';
      case StudyCategory.grammar:
        return '문법';
      case StudyCategory.sentenceArrange:
        return '문장배열';
      case StudyCategory.kana:
        return '가나';
    }
  }

  IconData get _categoryIcon {
    switch (widget.category) {
      case StudyCategory.vocabulary:
        return LucideIcons.bookOpen;
      case StudyCategory.grammar:
        return LucideIcons.languages;
      case StudyCategory.sentenceArrange:
        return LucideIcons.arrowUpDown;
      case StudyCategory.kana:
        return LucideIcons.type;
    }
  }

  String get _modeLabel {
    switch (_selectedMode) {
      case 'matching':
        return '매칭';
      case 'cloze':
        return '빈칸 채우기';
      case 'arrange':
        return '어순 배열';
      default:
        return '4지선다';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // For sentence arrange, we use VOCABULARY type with arrange mode
    final statsType = widget.category == StudyCategory.sentenceArrange
        ? 'VOCABULARY'
        : widget.category.apiType;

    final statsAsync = ref.watch(
      quizStatsProvider((level: widget.jlptLevel, type: statsType)),
    );
    final stats = statsAsync.hasValue ? statsAsync.value : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Quiz card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _categoryIcon,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.jlptLevel} $_categoryLabel 학습',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stats != null
                              ? '${stats.totalCount}개 $_categoryLabel · $_modeLabel'
                              : '$_categoryLabel · $_modeLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '10문제',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),

              // Mode selector (only for vocabulary & grammar)
              if (_showModeSelector) ...[
                const SizedBox(height: 16),
                QuizModeSelector(
                  selectedMode: _selectedMode,
                  availableModes: _availableModes,
                  onChanged: (mode) => setState(() => _selectedMode = mode),
                ),
              ],

              // Progress
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '학습 진행률',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${stats?.progress ?? 0}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (stats?.progress ?? 0) / 100,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHigh,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),

              // Start button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => widget.onStartQuiz(_selectedMode),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('학습 시작하기',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.flower2,
                          size: 16,
                          color: theme.colorScheme.onPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const MyStudyData(),
      ],
    );
  }
}
