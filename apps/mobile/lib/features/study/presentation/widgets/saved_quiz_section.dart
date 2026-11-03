import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/saved_quiz_model.dart';
import '../../providers/saved_quiz_provider.dart';
import '../quiz_launch.dart';
import '../study_entry_flow.dart';

/// Global entry point: changing today's level/category never hides old quizzes.
class SavedQuizSection extends ConsumerWidget {
  const SavedQuizSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentAccountIdProvider);
    final entries = ref.watch(savedQuizListProvider);
    if (!_accountCurrent(ref, owner)) return const SizedBox.shrink();
    final data = entries.asData?.value;
    final current = data?.accountId == owner ? data : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child:
                Text('저장된 퀴즈', style: Theme.of(context).textTheme.titleSmall),
          ),
          TextButton(
            key: const ValueKey('saved-quizzes-show-all'),
            onPressed: () async {
              if (!_accountCurrent(ref, owner)) return;
              await Navigator.of(context, rootNavigator: true).push<void>(
                MaterialPageRoute(builder: (_) => const SavedQuizListPage()),
              );
            },
            child: const Text('전체 보기'),
          ),
        ]),
        if (current != null) ...[
          if (current.sessions.isNotEmpty) ...[
            const Text('최근 시작한 퀴즈'),
            const SizedBox(height: 8),
            _SavedQuizTile(session: current.sessions.first),
          ] else
            const Text('답안을 저장한 퀴즈를 여기에서 이어 풀 수 있어요.'),
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
  const _SavedQuizTile({required this.session});
  final SavedQuizModel session;

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
              child: TextButton.icon(
                onPressed: _opening ? null : _open,
                icon: Icon(session.canResume
                    ? LucideIcons.playCircle
                    : LucideIcons.info),
                label:
                    Text(session.canResume ? session.actionLabel : '저장 기록 안내'),
              ),
            ),
          ],
        ),
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
