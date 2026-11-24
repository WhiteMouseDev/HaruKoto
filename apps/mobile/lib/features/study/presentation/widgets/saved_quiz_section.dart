import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/saved_quiz_model.dart';
import '../../providers/saved_quiz_provider.dart';
import '../quiz_launch.dart';
import '../study_entry_flow.dart';

/// Global entry point: changing today's level/category never hides old quizzes.
class SavedQuizSection extends ConsumerWidget {
  const SavedQuizSection({
    super.key,
    this.compact = false,
    this.redesigned = false,
    this.padding = EdgeInsets.zero,
  });

  final bool compact;
  final bool redesigned;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentAccountIdProvider);
    final entries = ref.watch(savedQuizListProvider);
    if (!_accountCurrent(ref, owner)) return const SizedBox.shrink();
    final data = entries.asData?.value;
    final current = data?.accountId == owner ? data : null;
    if (current != null &&
        (compact || redesigned && !current.refreshing) &&
        current.sessions.isEmpty &&
        current.nextCursor == null &&
        current.error == null) {
      return const SizedBox.shrink();
    }
    final showAll = TextButton(
      key: const ValueKey('saved-quizzes-show-all'),
      onPressed: () async {
        if (!_accountCurrent(ref, owner)) return;
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(builder: (_) => const SavedQuizListPage()),
        );
      },
      child: const Text('전체 보기'),
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!redesigned)
            Row(children: [
              Expanded(
                child: Text(
                  '저장된 퀴즈',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontFamily: compact ? redesignFontFamily : null,
                        fontWeight: compact ? FontWeight.w600 : null,
                      ),
                ),
              ),
              showAll,
            ]),
          if (current != null) ...[
            if (current.sessions.isNotEmpty) ...[
              if (!compact && !redesigned) ...[
                const Text('최근 시작한 퀴즈'),
                const SizedBox(height: 8),
              ],
              _SavedQuizTile(
                session: current.sessions.first,
                compact: compact,
                redesigned: redesigned,
              ),
            ] else if (!compact && !redesigned)
              const Text('답안을 저장한 퀴즈를 여기에서 이어 풀 수 있어요.'),
            if (redesigned &&
                (current.sessions.isNotEmpty || current.nextCursor != null))
              Align(alignment: Alignment.centerRight, child: showAll),
            if (redesigned && current.refreshing)
              const LinearProgressIndicator(
                semanticsLabel: '저장된 퀴즈 새로 확인 중',
              ),
            if (current.error != null)
              _SavedQuizError(
                error: current.error!,
                retry: () => ref.read(savedQuizListProvider.notifier).refresh(),
              ),
          ] else if (entries.hasError)
            _SavedQuizError(
              error: savedQuizLoadError(entries.error),
              retry: () => ref.invalidate(savedQuizListProvider),
            )
          else
            const LinearProgressIndicator(semanticsLabel: '저장된 퀴즈 확인 중'),
        ],
      ),
    );
  }
}

class SavedQuizListPage extends ConsumerWidget {
  const SavedQuizListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentAccountIdProvider);
    final entries = ref.watch(savedQuizListProvider);
    final data = entries.asData?.value;
    final current = data?.accountId == owner ? data : null;
    return Scaffold(
      appBar: AppBar(title: const Text('저장된 퀴즈 전체 보기')),
      body: !_accountCurrent(ref, owner)
          ? const Center(child: Text('현재 계정으로 다시 열어주세요.'))
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(savedQuizListProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const Text('모든 레벨 · 최근 시작 순'),
                  const SizedBox(height: 6),
                  const Text('다른 퀴즈를 시작해도 저장된 답안은 유지돼요.'),
                  const SizedBox(height: 16),
                  if (current != null) ...[
                    if (current.legacyFallback)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('현재 서버에서 확인할 수 있는 최근 퀴즈를 표시해요.'),
                      ),
                    if (current.refreshing)
                      const LinearProgressIndicator(
                          semanticsLabel: '저장된 퀴즈 새로 확인 중'),
                    for (final session in current.sessions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SavedQuizTile(session: session),
                      ),
                    if (current.sessions.isEmpty && current.nextCursor == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('아직 저장된 퀴즈가 없어요.'),
                      ),
                    if (current.error != null)
                      _SavedQuizError(
                        error: current.error!,
                        retry: () => !current.errorOnRefresh &&
                                current.nextCursor != null
                            ? ref
                                .read(savedQuizListProvider.notifier)
                                .loadMore()
                            : ref
                                .read(savedQuizListProvider.notifier)
                                .refresh(),
                      ),
                    if (current.nextCursor != null)
                      OutlinedButton(
                        key: const ValueKey('saved-quizzes-load-more'),
                        onPressed: current.loadingMore || current.refreshing
                            ? null
                            : () => ref
                                .read(savedQuizListProvider.notifier)
                                .loadMore(),
                        child: Text(current.loadingMore ? '불러오는 중…' : '더 보기'),
                      ),
                  ] else if (entries.hasError)
                    _SavedQuizError(
                      error: savedQuizLoadError(entries.error),
                      retry: () => ref.invalidate(savedQuizListProvider),
                    )
                  else
                    const Center(
                        child: CircularProgressIndicator(
                            semanticsLabel: '저장된 퀴즈 확인 중')),
                ],
              ),
            ),
    );
  }
}

bool _accountCurrent(WidgetRef ref, String? owner) =>
    owner != null && ref.read(currentAccountReaderProvider)() == owner;

class _SavedQuizTile extends ConsumerStatefulWidget {
  const _SavedQuizTile({
    required this.session,
    this.compact = false,
    this.redesigned = false,
  });
  final SavedQuizModel session;
  final bool compact;
  final bool redesigned;

  @override
  ConsumerState<_SavedQuizTile> createState() => _SavedQuizTileState();
}

class _SavedQuizTileState extends ConsumerState<_SavedQuizTile> {
  bool _opening = false;

  Future<void> _open() async {
    final owner = ref.read(currentAccountIdProvider);
    if (_opening || !_accountCurrent(ref, owner)) return;
    setState(() => _opening = true);
    try {
      final session = widget.session;
      if (!session.canResume) {
        await showQuizResumeUnavailable(context,
            legacy: session.resumeStatus == 'legacy_unavailable');
        return;
      }
      await openQuizPageForSession(
        context,
        quizType: session.quizType,
        jlptLevel: session.jlptLevel,
        count: session.totalQuestions,
        resumeSessionId: session.id,
        mode: session.mode,
      );
      if (mounted && _accountCurrent(ref, owner)) {
        await ref.read(savedQuizListProvider.notifier).refresh();
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final theme = Theme.of(context);
    if (widget.redesigned) {
      return _PracticeResumeCard(
        key: ValueKey('saved-quiz-${session.id}'),
        session: session,
        onOpen: _opening ? null : _open,
      );
    }
    final action = TextButton.icon(
      onPressed: _opening ? null : _open,
      icon: Icon(session.canResume ? LucideIcons.playCircle : LucideIcons.info),
      label: Text(session.canResume ? session.actionLabel : '저장 기록 안내'),
    );
    if (widget.compact) {
      return Container(
        key: ValueKey('saved-quiz-${session.id}'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${session.jlptLevel} · ${session.categoryLabel}',
                        style: const TextStyle(
                          fontFamily: redesignFontFamily,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(
                      session.canResume
                          ? '${session.answeredCount}/${session.totalQuestions}문제 저장됨'
                          : '이어 풀 수 없는 기록',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(child: action),
          ],
        ),
      );
    }
    return Card(
      key: ValueKey('saved-quiz-${session.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(LucideIcons.bookOpen,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${session.jlptLevel} · ${session.categoryLabel}',
                    style: theme.textTheme.titleSmall),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${session.modeLabel} · ${session.startedLabel}'),
            const SizedBox(height: 8),
            if (session.canResume) ...[
              Text('${session.answeredCount}/${session.totalQuestions}문제 저장됨'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: session.answeredCount / session.totalQuestions,
                semanticsLabel:
                    '저장된 퀴즈 진행률 ${session.answeredCount}/${session.totalQuestions}문제',
              ),
            ] else
              const Text('이 퀴즈는 지금 이어 풀 수 없어요. 기존 학습 기록은 유지됩니다.'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeResumeCard extends StatelessWidget {
  const _PracticeResumeCard({
    super.key,
    required this.session,
    required this.onOpen,
  });

  final SavedQuizModel session;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final (title, actionLabel) = switch (session) {
      SavedQuizModel(readyForResult: true) => (
          '저장된 퀴즈 결과',
          session.actionLabel
        ),
      SavedQuizModel(canResume: true) => ('진행 중인 퀴즈 이어풀기', '퀴즈 풀기'),
      _ => ('저장된 퀴즈', '저장 기록 안내'),
    };
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: light
                ? AppColors.redesignForeground
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        DefaultTextStyle(
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 12,
            height: 1.4,
            color: light
                ? AppColors.redesignMutedForeground
                : theme.colorScheme.onSurfaceVariant,
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: light
                      ? AppColors.redesignVocabulary
                      : theme.colorScheme.primaryContainer,
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  child: Text(
                    session.jlptLevel,
                    style: TextStyle(
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: light
                          ? Colors.white
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              Text('${session.categoryLabel} ·',
                  semanticsLabel: session.categoryLabel),
              Text(
                session.canResume
                    ? '${session.answeredCount}/${session.totalQuestions}문제 저장됨'
                    : '이어 풀 수 없는 기록',
              ),
            ],
          ),
        ),
      ],
    );
    final action = FilledButton(
      onPressed: onOpen,
      style: FilledButton.styleFrom(
        backgroundColor: light ? AppColors.brandPink : null,
        foregroundColor: light ? Colors.white : null,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: redesignFontFamily,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(
        actionLabel,
        semanticsLabel: session.canResume && !session.readyForResult
            ? '저장한 ${session.categoryLabel} 퀴즈 이어 풀기'
            : null,
        textAlign: TextAlign.center,
      ),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 83),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: light ? Colors.white : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: light ? AppColors.redesignOutline : theme.colorScheme.outline,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (constraints.maxWidth < 264 * scale) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                description,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _SavedQuizError extends StatelessWidget {
  const _SavedQuizError({required this.error, required this.retry});
  final ApiException error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(error.userMessage),
          TextButton(onPressed: retry, child: const Text('다시 확인')),
        ]),
      );
}
