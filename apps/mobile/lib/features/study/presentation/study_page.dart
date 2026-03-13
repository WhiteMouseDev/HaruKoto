import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/study_provider.dart';
import 'quiz_page.dart';
import 'widgets/resume_banner.dart';
import 'widgets/tab_switcher.dart';
import 'widgets/recommend_tab.dart';
import 'widgets/free_tab.dart';
import 'widgets/my_study_data.dart';
import 'widgets/study_skeleton.dart';

class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({super.key});

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  int _studyTab = 0; // 0 = recommend, 1 = free
  String _selectedLevel = 'N5';
  String _selectedType = 'VOCABULARY';
  String _quizMode = 'normal';

  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  static const _quizTypes = [
    ('VOCABULARY', '단어'),
    ('GRAMMAR', '문법'),
  ];

  void _startQuiz({String? mode, String? resumeId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPage(
          quizType: _selectedType,
          jlptLevel: _selectedLevel,
          count: 10,
          mode: mode ??
              (_quizMode != 'normal' ? _quizMode : null),
          resumeSessionId: resumeId,
        ),
      ),
    );
  }

  String get _modeLabel {
    switch (_quizMode) {
      case 'matching':
        return '매칭';
      case 'cloze':
        return '빈칸 채우기';
      case 'arrange':
        return '어순 배열';
      case 'typing':
        return '단어 쓰기';
      default:
        return '4지선다';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incompleteAsync =
        ref.watch(incompleteQuizProvider);
    final recsAsync = ref.watch(recommendationsProvider);
    final statsAsync = ref.watch(
      quizStatsProvider(
          (level: _selectedLevel, type: _selectedType)),
    );

    // Multi-provider composition: manual handling since loading state
    // depends on recsAsync having no prior value.
    final isLoading =
        recsAsync.isLoading && !recsAsync.hasValue;

    if (isLoading) {
      return const Scaffold(
          body: SafeArea(child: StudySkeleton()));
    }

    final incompleteSession =
        incompleteAsync.hasValue ? incompleteAsync.value : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
            ref.invalidate(recommendationsProvider);
            ref.invalidate(quizStatsProvider((
              level: _selectedLevel,
              type: _selectedType
            )));
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (incompleteSession != null)
                ResumeBanner(session: incompleteSession),
              Padding(
                padding: const EdgeInsets.only(
                    top: 8, bottom: 16),
                child: Text(
                  'JLPT 학습',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TabSwitcher(
                activeTab: _studyTab,
                onTabChanged: (tab) =>
                    setState(() => _studyTab = tab),
              ),
              const SizedBox(height: 16),
              if (_studyTab == 0)
                RecommendTab(
                  recs: recsAsync,
                  onInvalidate: () =>
                      ref.invalidate(recommendationsProvider),
                )
              else
                FreeTab(
                  selectedLevel: _selectedLevel,
                  selectedType: _selectedType,
                  quizMode: _quizMode,
                  modeLabel: _modeLabel,
                  jlptLevels: _jlptLevels,
                  quizTypes: _quizTypes,
                  statsAsync: statsAsync,
                  onLevelChanged: (level) =>
                      setState(() => _selectedLevel = level),
                  onTypeChanged: (type) => setState(
                      () => _selectedType = type),
                  onModeChanged: (mode) =>
                      setState(() => _quizMode = mode),
                  onStartQuiz: () => _startQuiz(),
                ),
              const SizedBox(height: 24),
              const MyStudyData(),
            ],
          ),
        ),
      ),
    );
  }
}
