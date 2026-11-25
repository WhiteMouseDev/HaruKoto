import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/text_theme.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../home/data/models/dashboard_model.dart';
import '../../home/providers/home_provider.dart';
import '../../study/presentation/quiz_launch.dart';
import '../../study/presentation/widgets/free_quiz_selection.dart';
import '../../study/presentation/widgets/free_quiz_sheet.dart';
import '../../study/presentation/widgets/saved_quiz_section.dart';
import '../../study/providers/saved_quiz_provider.dart';

const _quizQuestionCount = 10;

enum _QuizCategory {
  vocabulary('단어', 'VOCABULARY', '단어 퀴즈를 풀면서 어휘력을 늘려봐요!', 63),
  grammar('문법', 'GRAMMAR', '문장에 쓰이는 문법을 익혀요.', 63),
  kanji('한자', 'KANJI', '한자의 뜻과 읽는 법을 확인해요.', 63),
  listening('리스닝', 'LISTENING', '일본어 음성을 듣고 알맞은 답을 골라요.', 74),
  sentenceArrange('문장배열', 'SENTENCE_ARRANGE', '단어를 배열해 문장을 완성해요.', 86);

  final String label;
  final String apiType;
  final String description;
  final double tabWidth;

  const _QuizCategory(
      this.label, this.apiType, this.description, this.tabWidth);

  bool get usesFreeQuizSheet => this == vocabulary || this == grammar;

  String? get defaultMode => this == sentenceArrange ? 'arrange' : null;
}

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  late _QuizCategory _selectedCategory;
  bool _openingQuiz = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categoryFromString(widget.initialCategory);
  }

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory) {
      _selectedCategory = _categoryFromString(widget.initialCategory);
    }
  }

  _QuizCategory _categoryFromString(String? category) =>
      _QuizCategory.values.firstWhere(
        (value) => value.apiType == category,
        orElse: () => _QuizCategory.vocabulary,
      );

  bool _isCurrent(String? owner) =>
      owner != null &&
      ref.read(currentAccountIdProvider) == owner &&
      ref.read(currentAccountReaderProvider)() == owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = ref.watch(currentAccountIdProvider);
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;
    final accountCurrent = _isCurrent(owner);
    final dashboard = accountCurrent ? ref.watch(dashboardProvider) : null;
    final today = dashboard == null || dashboard.isLoading || dashboard.hasError
        ? null
        : dashboard.asData?.value.today;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Semantics(
                header: true,
                child:
                    Text('퀴즈', style: _practiceText(theme, 20, strong: true)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (!_isCurrent(owner)) return;
                  ref.invalidate(dashboardProvider);
                  await ref.read(savedQuizListProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _QuizCategoryTabs(
                          selectedCategory: _selectedCategory,
                          onChanged: (category) =>
                              setState(() => _selectedCategory = category),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      sliver: SliverList.list(
                        children: [
                          _QuizHero(
                            category: _selectedCategory,
                            onStart: accountCurrent && !_openingQuiz
                                ? () => _startSelectedQuiz(owner, jlptLevel)
                                : null,
                          ),
                          const SizedBox(height: 40),
                          _TodayRecord(
                            today: today,
                            loading: dashboard?.isLoading == true,
                            onRetry: accountCurrent
                                ? () => ref.invalidate(dashboardProvider)
                                : null,
                          ),
                          const SizedBox(height: 40),
                          const SavedQuizSection(
                            redesigned: true,
                            padding: EdgeInsets.only(bottom: 20),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              '퀴즈 기록',
                              style: _practiceText(theme, 16, strong: true),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _RecordTile(
                            icon: 'wordbook',
                            iconSize: 28,
                            label: '단어장',
                            destination: '/study/wordbook',
                          ),
                          const SizedBox(height: 8),
                          const _RecordTile(
                            icon: 'wrong',
                            label: '오답노트',
                            destination: '/study/wrong-answers',
                          ),
                          const SizedBox(height: 8),
                          const _RecordTile(
                            icon: 'studied',
                            label: '학습한 단어',
                            destination: '/study/learned-words',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSelectedQuiz(String? owner, String jlptLevel) async {
    if (_openingQuiz || !_isCurrent(owner)) return;
    final category = _selectedCategory;
    setState(() => _openingQuiz = true);
    try {
      if (category.usesFreeQuizSheet) {
        final selection = await showModalBottomSheet<FreeQuizSelection>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : null,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => FreeQuizSheet(
            initialSelection: FreeQuizSelection(
              level: jlptLevel,
              type: category.apiType,
            ),
          ),
        );
        if (selection == null || !mounted || !_isCurrent(owner)) return;
        await openQuizPageForSession(
          context,
          quizType: selection.type,
          jlptLevel: selection.level,
          count: _quizQuestionCount,
          mode: selection.mode == 'normal' ? null : selection.mode,
        );
      } else {
        await openQuizPageForSession(
          context,
          quizType: category.apiType,
          jlptLevel: jlptLevel,
          count: _quizQuestionCount,
          mode: category.defaultMode,
        );
      }
    } finally {
      if (mounted) setState(() => _openingQuiz = false);
    }
  }
}

class _QuizCategoryTabs extends StatelessWidget {
  const _QuizCategoryTabs({
    required this.selectedCategory,
    required this.onChanged,
  });

  final _QuizCategory selectedCategory;
  final ValueChanged<_QuizCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        spacing: 4,
        children: [
          for (final category in _QuizCategory.values)
            TextButton(
              key: ValueKey('practice-category-${category.apiType}'),
              style: TextButton.styleFrom(
                backgroundColor: category == selectedCategory
                    ? light
                        ? AppColors.redesignStrong
                        : colors.onSurface
                    : light
                        ? AppColors.redesignControl
                        : colors.surfaceContainerHigh,
                foregroundColor: category == selectedCategory
                    ? light
                        ? Colors.white
                        : colors.surface
                    : light
                        ? AppColors.redesignForeground
                        : colors.onSurfaceVariant,
                minimumSize: Size(category.tabWidth, 32),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  letterSpacing: -0.325,
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: () => onChanged(category),
              child: Semantics(
                selected: category == selectedCategory,
                inMutuallyExclusiveGroup: true,
                child: Text(category.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizHero extends StatelessWidget {
  const _QuizHero({required this.category, required this.onStart});

  // The 42-point button fill sits inside a 48-point interaction area.
  static const _buttonHitInset = 3.0;
  static const _secondaryText = Color(0xFF505050);

  final _QuizCategory category;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 - _buttonHitInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colors.surfaceContainerLowest,
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/figma-practice-hero.png',
                          width: 18,
                          height: 17,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: colors.surfaceContainerLowest,
                  ),
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 59, minHeight: 28),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      '$_quizQuestionCount문제',
                      style: _practiceText(theme, 13, height: 1.5, muted: true)
                          .copyWith(color: light ? _secondaryText : null),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${category.label} 퀴즈 풀기',
              style: _practiceText(theme, 18, strong: true),
            ),
            const SizedBox(height: 4),
            Text(
              category.description,
              style: _practiceText(theme, 13, height: 1.5, muted: true)
                  .copyWith(color: light ? _secondaryText : null),
            ),
            const SizedBox(height: 12 - _buttonHitInset),
            FilledButton(
              key: const ValueKey('practice-start-quiz'),
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: light ? AppColors.brandPink : null,
                foregroundColor: light ? Colors.white : null,
                minimumSize: const Size(0, 42),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  letterSpacing: -0.35,
                ),
              ),
              child: const Text('퀴즈 풀기', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayRecord extends StatelessWidget {
  const _TodayRecord({
    required this.today,
    required this.loading,
    required this.onRetry,
  });

  final TodayStats? today;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final total = today?.totalAnswers;
    final correct = today?.correctAnswers;
    final counts =
        total != null && correct != null && total >= correct && correct >= 0
            ? (total: total, correct: correct, wrong: total - correct)
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            '오늘의 기록',
            style: _practiceText(theme, 16, strong: true),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  light ? AppColors.redesignOutline : theme.colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerLowest,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: counts != null || loading
                ? Semantics(
                    container: true,
                    liveRegion: counts == null,
                    label:
                        counts == null ? '오늘의 기록 불러오는 중' : '오늘 완료한 전체 유형의 퀴즈',
                    excludeSemantics: counts == null,
                    child: Row(
                      children: [
                        Expanded(
                          child: _RecordMetric(
                            label: '오늘 푼 퀴즈',
                            semanticsLabel: '푼 문제',
                            count: counts?.total,
                            emphasized: true,
                          ),
                        ),
                        Expanded(
                          child: _RecordMetric(
                              label: '정답', count: counts?.correct),
                        ),
                        Expanded(
                          child:
                              _RecordMetric(label: '오답', count: counts?.wrong),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        '오늘의 기록을 확인하지 못했어요',
                        style: _practiceText(theme, 13, muted: true),
                        textAlign: TextAlign.center,
                      ),
                      if (onRetry != null)
                        TextButton(
                          key: const ValueKey('practice-today-retry'),
                          onPressed: onRetry,
                          child: const Text('다시 확인'),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecordMetric extends StatelessWidget {
  const _RecordMetric({
    required this.label,
    required this.count,
    this.semanticsLabel,
    this.emphasized = false,
  });

  final String label;
  final int? count;
  final String? semanticsLabel;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.light
        ? AppColors.brandPink
        : AppColors.sakuraContainer;
    final countStyle = _practiceText(theme, 18, strong: true).copyWith(
      color: emphasized ? accent : null,
    );
    return Semantics(
      container: true,
      label: count == null ? null : '${semanticsLabel ?? label} $count개',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            if (count == null)
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(18) * 1.4,
                child: const Center(
                  child: AppSkeletonBlock(width: 36, height: 12),
                ),
              )
            else
              Text.rich(
                TextSpan(
                  text: '$count',
                  children: [
                    TextSpan(
                      text: '개',
                      style: _practiceText(theme, 13, height: 1.5),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: countStyle,
              ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style:
                  _practiceText(theme, 12, height: 1.5, muted: true).copyWith(
                color: theme.brightness == Brightness.light
                    ? const Color(0xFF767676)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.destination,
    this.iconSize = 32,
  });

  final String icon;
  final String label;
  final String destination;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: light ? AppColors.redesignOutline : theme.colorScheme.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(destination),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 21.5, 10),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 34,
                  child: Center(
                    child: Image.asset(
                      'assets/icons/figma-practice-$icon.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    style: _practiceText(theme, 14, height: 1.5)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/icons/figma-home-arrow.png',
                  width: 6.25,
                  height: 11,
                  color: light
                      ? const Color(0xFF81818D)
                      : theme.colorScheme.onSurfaceVariant,
                  excludeFromSemantics: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _practiceText(
  ThemeData theme,
  double size, {
  bool strong = false,
  bool muted = false,
  double height = 1.4,
}) {
  final light = theme.brightness == Brightness.light;
  return TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: size,
    fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
    height: height,
    letterSpacing: -size * 0.025,
    color: muted
        ? light
            ? AppColors.redesignMutedForeground
            : theme.colorScheme.onSurfaceVariant
        : light
            ? AppColors.redesignForeground
            : theme.colorScheme.onSurface,
  );
}
