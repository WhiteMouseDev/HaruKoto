import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/network/api_exception.dart';
import '../domain/katakana_pilot.dart';
import '../domain/kana_writing_progress.dart';
import '../providers/kana_writing_progress_provider.dart';
import '../providers/katakana_pilot_review_provider.dart';
import 'widgets/katakana_pilot_strokes.dart';

class KanaPilotPage extends ConsumerWidget {
  const KanaPilotPage({super.key, this.hiragana = false});

  final bool hiragana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountIdProvider);
    final label = hiragana ? '히라가나' : '가타카나';
    return Scaffold(
      appBar: AppBar(title: Text('$label 집중 연습')),
      body: SafeArea(
        child: account == null
            ? Center(child: Text('로그인 후 $label를 연습해 보세요.'))
            : _PilotSession(
                key: ValueKey((account, hiragana)),
                owner: account,
                hiragana: hiragana,
              ),
      ),
    );
  }
}

enum _Step { compare, recall, word }

enum _PracticeMode { comparison, row, dailyReview }

class _PilotSession extends ConsumerStatefulWidget {
  const _PilotSession({
    super.key,
    required this.owner,
    required this.hiragana,
  });

  final String owner;
  final bool hiragana;

  @override
  ConsumerState<_PilotSession> createState() => _PilotSessionState();
}

class _PilotSessionState extends ConsumerState<_PilotSession>
    with WidgetsBindingObserver {
  List<KanaPracticeLetter> _letters = const [];
  _PracticeMode _mode = _PracticeMode.comparison;
  int _index = 0;
  _Step _step = _Step.compare;
  int _writingAttempt = 0;
  bool _hasInk = false;
  bool _showExample = false;
  int? _selectedIndex;
  List<List<Offset>> _strokes = const [];
  VoidCallback? _afterProgressSave;
  bool _saving = false;
  String? _saveError;

  KanaPracticeLetter get _letter => _letters[_index];
  bool get _dailyReview => _mode == _PracticeMode.dailyReview;
  KanaWritingScope get _scope =>
      KanaWritingScope(owner: widget.owner, hiragana: widget.hiragana);
  KanaWritingProgressState get _writingState =>
      ref.read(kanaWritingProgressProvider(_scope));
  bool get _isOwner => ref.read(currentAccountReaderProvider)() == widget.owner;
  bool get _canInteract =>
      _isOwner &&
      !_saving &&
      (_dailyReview ? !_writingState.busy : _writingState.canAct);
  bool get _canActOnWord => _canInteract && _step == _Step.word;

  KanaWritingSession _snapshot({
    _Step? step,
    bool? showExample,
    int? selectedIndex,
    bool clearInk = false,
  }) =>
      KanaWritingSession(
        letters: _letters,
        index: _index,
        step: KanaWritingStep.values[(step ?? _step).index],
        mode: _mode == _PracticeMode.row
            ? KanaWritingMode.row
            : KanaWritingMode.comparison,
        showExample: (step ?? _step) == _Step.recall
            ? showExample ?? _showExample
            : false,
        selectedIndex: selectedIndex ?? _selectedIndex,
        strokes:
            clearInk || (step ?? _step) != _Step.recall ? const [] : _strokes,
      );

  void _applySession(KanaWritingSession session) {
    setState(() {
      _letters = session.letters;
      _mode = session.mode == KanaWritingMode.row
          ? _PracticeMode.row
          : _PracticeMode.comparison;
      _index = session.index;
      _step = _Step.values[session.step.index];
      _showExample = session.showExample;
      _selectedIndex = session.selectedIndex;
      _strokes = session.strokes;
      _hasInk = _strokes.isNotEmpty;
      _writingAttempt++;
      _saveError = null;
    });
  }

  Future<void> _persist(KanaWritingSession? session, VoidCallback after,
      {KanaPracticeRow? completedRow}) async {
    if (!_isOwner || !_writingState.canAct) return;
    _afterProgressSave = after;
    final controller = ref.read(kanaWritingProgressProvider(_scope).notifier);
    if (session == null) {
      await controller.finishSession(completedRow: completedRow);
    } else {
      await controller.saveSession(session);
    }
    if (!mounted ||
        !_isOwner ||
        _writingState.error != null ||
        _writingState.busy) {
      return;
    }
    _afterProgressSave = null;
    after();
  }

  Future<void> _retryWriting() async {
    if (!_isOwner || _writingState.busy) return;
    await ref.read(kanaWritingProgressProvider(_scope).notifier).retry();
    if (!mounted ||
        !_isOwner ||
        _writingState.error != null ||
        _writingState.busy) {
      return;
    }
    final after = _afterProgressSave;
    _afterProgressSave = null;
    after?.call();
  }

  Future<void> _goTo(_Step step) async {
    if (!_canInteract) return;
    if (_dailyReview) {
      setState(() => _step = step);
      return;
    }
    final next = _snapshot(step: step);
    await _persist(next, () => _applySession(next));
  }

  Future<void> _showComparison(bool show) async {
    if (!_canInteract) return;
    final next = _snapshot(showExample: show, clearInk: !show);
    await _persist(next, () => _applySession(next));
  }

  Future<void> _inkChanged(List<List<Offset>> strokes) async {
    if (!_canInteract || _dailyReview) return;
    setState(() {
      _strokes = strokes;
      _hasInk = strokes.isNotEmpty;
    });
    await _persist(_snapshot(), () {});
  }

  Future<void> _selectWord(int index) async {
    if (!_canActOnWord) return;
    if (_dailyReview) {
      setState(() => _selectedIndex = index);
      return;
    }
    final next = _snapshot(selectedIndex: index);
    await _persist(next, () => _applySession(next));
  }

  void _toPicker() {
    if (!_isOwner ||
        _saving ||
        _writingState.busy ||
        _afterProgressSave != null) {
      return;
    }
    setState(() {
      _letters = const [];
      _index = 0;
      _mode = _PracticeMode.comparison;
      _resetLetter();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(katakanaPilotLocalDayProvider.notifier).refresh();
    }
  }

  Future<void> _start(
    List<KanaPracticeLetter> letters, {
    _PracticeMode mode = _PracticeMode.comparison,
  }) async {
    if (!_isOwner ||
        _saving ||
        _writingState.busy ||
        _afterProgressSave != null) {
      return;
    }
    if (mode == _PracticeMode.dailyReview) {
      setState(() {
        _letters = letters;
        _mode = mode;
        _index = 0;
        _resetLetter();
      });
      return;
    }
    if (!_writingState.canAct) return;
    if (_writingState.progress?.session != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('새 연습을 시작할까요?'),
          content: const Text('이 기기에 저장된 이전 쓰기 위치가 새 연습으로 바뀌어요. 복습 표시는 유지돼요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('새 연습 시작')),
          ],
        ),
      );
      if (!mounted || replace != true || !_isOwner || !_writingState.canAct) {
        return;
      }
    }
    final next = KanaWritingSession(
      letters: letters,
      index: 0,
      step: KanaWritingStep.compare,
      mode: mode == _PracticeMode.row
          ? KanaWritingMode.row
          : KanaWritingMode.comparison,
    );
    await _persist(next, () => _applySession(next));
  }

  void _resetLetter() {
    _step = _dailyReview ? _Step.word : _Step.compare;
    _hasInk = false;
    _strokes = const [];
    _showExample = false;
    _selectedIndex = null;
    _saveError = null;
  }

  Future<void> _next() async {
    if (!_canActOnWord) return;
    if (_dailyReview) {
      ref.read(katakanaPilotLocalDayProvider.notifier).refresh();
      final day = ref.read(katakanaPilotLocalDayProvider);
      final saved = await _save(
        (review) => review.completeDailyReview(_letter, day),
      );
      if (!mounted || !saved || !_canActOnWord) return;
      setState(() {
        if (_index + 1 == _letters.length) {
          _letters = const [];
          _mode = _PracticeMode.comparison;
          _index = 0;
        } else {
          _index++;
        }
        _resetLetter();
      });
      return;
    }
    if (_index + 1 == _letters.length) {
      final row = _snapshot().row;
      await _persist(null, _toPicker,
          completedRow: row?.section == KanaPracticeSection.basic ? row : null);
    } else {
      final next = KanaWritingSession(
        letters: _letters,
        index: _index + 1,
        step: KanaWritingStep.compare,
        mode: _mode == _PracticeMode.row
            ? KanaWritingMode.row
            : KanaWritingMode.comparison,
      );
      await _persist(next, () => _applySession(next));
    }
  }

  Future<bool> _save(Future<void> Function(KatakanaPilotReview) update) async {
    if (!_canActOnWord) return false;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await update(ref.read(katakanaPilotReviewProvider.notifier));
      return true;
    } on ApiException catch (error) {
      if (mounted) setState(() => _saveError = error.userMessage);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final writing = ref.watch(kanaWritingProgressProvider(_scope));
    final review = ref.watch(katakanaPilotReviewProvider);
    final savedReview =
        review.isLoading || review.hasError ? null : review.asData?.value;
    final day = ref.watch(katakanaPilotLocalDayProvider);
    final theme = Theme.of(context);
    final isStart = _letters.isEmpty;

    return PopScope<void>(
      canPop: !_saving && !writing.busy && _afterProgressSave == null,
      child: ListView(
        key: ValueKey((isStart, _index, _step)),
        padding: const EdgeInsets.all(AppSizes.md),
        children: isStart
            ? [
                ..._writingStart(theme, writing),
                ..._startContent(theme, savedReview, day, review.hasError),
              ]
            : [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('kana-writing-picker'),
                    onPressed:
                        _saving || writing.busy || _afterProgressSave != null
                            ? null
                            : _toPicker,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('연습 목록'),
                  ),
                ),
                if (!_dailyReview) ..._writingStatus(writing),
                Text(
                  _dailyReview
                      ? '${_index + 1}/${_letters.length} 글자 · 새 단어 복습'
                      : '${_index + 1}/${_letters.length} 글자 · ${_step.index + 1}/3 단계',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: AppSizes.sm),
                ...switch (_step) {
                  _Step.compare => _compareContent(theme),
                  _Step.recall => _recallContent(theme),
                  _Step.word =>
                    _wordContent(theme, savedReview?.marked, review.hasError),
                },
              ],
      ),
    );
  }

  List<Widget> _writingStatus(KanaWritingProgressState writing) => [
        SizedBox(
          height: 24,
          child: Semantics(
            liveRegion: true,
            child: Text(
              writing.loading
                  ? '쓰기 위치를 불러오고 있어요.'
                  : writing.busy
                      ? '쓰기 위치 저장 중…'
                      : '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        if (writing.error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(writing.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(
              onPressed: writing.busy ? null : _retryWriting,
              child: Text(writing.progress == null || writing.blocked
                  ? '쓰기 위치 다시 불러오기'
                  : '쓰기 위치 저장 다시 시도')),
        ],
      ];

  List<Widget> _writingStart(
      ThemeData theme, KanaWritingProgressState writing) {
    final progress = writing.progress;
    final session = progress?.session;
    final row = progress?.recommendedRow;
    const labels = ['획순 보기', '가리고 쓰기', '단어에서 찾기'];
    return [
      ..._writingStatus(writing),
      if (session != null) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('이어서 쓰기', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSizes.sm),
                Text(
                    '${session.letter.glyph} · ${session.index + 1}/${session.letters.length} 글자 · ${labels[session.step.index]}'),
                const SizedBox(height: AppSizes.sm),
                FilledButton(
                  key: const ValueKey('kana-writing-resume'),
                  onPressed: writing.canAct && !_saving
                      ? () => _applySession(session)
                      : null,
                  child: const Text('쓰기 연습 이어하기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
      ],
      if (progress != null) ...[
        Text('기본 46자, 한 행씩 써보세요', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSizes.sm),
        Text('이 기기의 기본 쓰기 연습 ${progress.completedBasicCount}/46자 완료'),
        const Text('처음에는 위에서부터 한 행씩 추천해요. 원하는 행도 자유롭게 고를 수 있어요.'),
        if (row != null) ...[
          const SizedBox(height: AppSizes.sm),
          Text('다음 추천: ${row.label(hiragana: widget.hiragana)}',
              style: theme.textTheme.titleMedium),
          FilledButton(
            key: const ValueKey('kana-writing-recommendation'),
            onPressed: writing.canAct && !_saving
                ? () => _start(row.letters(hiragana: widget.hiragana),
                    mode: _PracticeMode.row)
                : null,
            child: const Text('추천 행 연습하기'),
          ),
        ] else ...[
          const SizedBox(height: AppSizes.sm),
          const Text('기본 46자 쓰기 연습을 마쳤어요. 헷갈린 글자를 복습하거나 탁음·작은 글자도 연습해 보세요.'),
        ],
        const SizedBox(height: AppSizes.lg),
      ],
    ];
  }

  List<Widget> _startContent(
    ThemeData theme,
    KatakanaPilotReviewState? review,
    DateTime day,
    bool loadFailed,
  ) {
    final hiragana = widget.hiragana;
    final List<KanaPracticeLetter> scriptLetters =
        hiragana ? HiraganaPilotLetter.values : KatakanaPilotLetter.values;
    final reviewLetters = scriptLetters
        .where((letter) => review?.marked.contains(letter) ?? false)
        .toList();
    final due = review?.dueOn(day) ?? const <KanaPracticeLetter>{};
    final dailyLetters = reviewLetters.where(due.contains).toList();
    return [
      Text(
        hiragana ? '기본 히라가나 쓰기' : '기본 가타카나 쓰기',
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSizes.sm),
      const Text('연습할 행을 골라 한 글자씩 획순을 보고 써보세요.'),
      const SizedBox(height: AppSizes.sm),
      _rowButtons(theme, KanaPracticeSection.basic),
      if (!hiragana) ...[
        const SizedBox(height: AppSizes.lg),
        Text('닮은 글자, 어떻게 다를까요?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSizes.sm),
        const Text('획순을 비교하고, 본보기를 가려 써본 뒤, 단어에서 같은 글자를 찾아보세요.'),
        const SizedBox(height: AppSizes.lg),
        Text('묶음 골라 연습', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSizes.sm),
        for (final group in KatakanaPracticeGroup.values)
          if (group != KatakanaPracticeGroup.firstRow) ...[
            _groupButton(
              theme,
              id: 'katakana-practice-group-${group.name}',
              label: group.label,
              letters: group.letters,
            ),
            const SizedBox(height: AppSizes.sm),
          ],
      ],
      const SizedBox(height: AppSizes.md),
      Text('이 기기에 저장된 복습', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSizes.sm),
      if (loadFailed)
        _reviewRetry()
      else if (review == null)
        const Text('복습 기록을 불러오고 있어요.')
      else if (reviewLetters.isEmpty)
        const Text('연습 중 ‘헷갈렸어요’를 누른 글자가 여기에 모여요.')
      else ...[
        Text(
          reviewLetters.map((letter) => letter.glyph).join(' · '),
          locale: const Locale('ja'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSizes.sm),
        if (dailyLetters.isEmpty)
          const Text('기기 날짜가 바뀌면 새 단어로 복습할 수 있어요.')
        else ...[
          Text('오늘 새 단어로 복습할 글자 ${dailyLetters.length}개'),
          const SizedBox(height: AppSizes.sm),
          FilledButton(
            onPressed: () =>
                _start(dailyLetters, mode: _PracticeMode.dailyReview),
            child: const Text('새 단어로 복습'),
          ),
        ],
        const SizedBox(height: AppSizes.sm),
        OutlinedButton(
          onPressed: () => _start(reviewLetters),
          child: const Text('헷갈린 글자 복습'),
        ),
      ],
      const SizedBox(height: AppSizes.lg),
      Text('탁음·반탁음 쓰기', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      _rowButtons(theme, KanaPracticeSection.voiced),
      const SizedBox(height: AppSizes.lg),
      Text('작은 글자 쓰기', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      _rowButtons(theme, KanaPracticeSection.small),
    ];
  }

  Widget _rowButtons(ThemeData theme, KanaPracticeSection section) {
    final hiragana = widget.hiragana;
    final script = hiragana ? 'hiragana' : 'katakana';
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        for (final row in KanaPracticeRow.values)
          if (row.section == section &&
              row.letters(hiragana: hiragana).isNotEmpty)
            _groupButton(
              theme,
              id: '$script-practice-group-${row.name}',
              label: row.label(hiragana: hiragana),
              letters: row.letters(hiragana: hiragana),
              mode: _PracticeMode.row,
            ),
      ],
    );
  }

  Widget _groupButton(
    ThemeData theme, {
    required String id,
    required String label,
    required List<KanaPracticeLetter> letters,
    _PracticeMode mode = _PracticeMode.comparison,
  }) =>
      FilledButton.tonal(
        key: ValueKey(id),
        onPressed: _writingState.canAct && !_saving
            ? () => _start(letters, mode: mode)
            : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: mode == _PracticeMode.row
              ? const EdgeInsets.symmetric(horizontal: AppSizes.sm)
              : null,
        ),
        child: Text(
          label,
          locale: const Locale('ja'),
          style: mode == _PracticeMode.row
              ? theme.textTheme.titleMedium
              : theme.textTheme.titleLarge,
        ),
      );

  List<Widget> _compareContent(ThemeData theme) {
    final letter = _letter;
    final showComparison = _mode != _PracticeMode.row &&
        letter is KatakanaPilotLetter &&
        letter.comparisonLetters.length > 1;
    return [
      Text(showComparison ? '획순 비교' : '획순 보기',
          style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      Text(showComparison
          ? '번호와 선으로 각 획의 시작점을 확인하세요. 획의 수와 위치, 그리는 방향을 비교해 보세요.'
          : '획순을 재생해 각 획을 어디서 시작하고 어느 방향으로 쓰는지 확인하세요.'),
      const SizedBox(height: AppSizes.md),
      KatakanaStrokeComparison(letter: letter, showComparison: showComparison),
      const SizedBox(height: AppSizes.md),
      FilledButton(
        onPressed: _canInteract ? () => _goTo(_Step.recall) : null,
        child: const Text('가리고 쓰기'),
      ),
    ];
  }

  List<Widget> _recallContent(ThemeData theme) {
    final koreanHint = widget.hiragana ||
        _letter.exampleKind == KanaPracticeExampleKind.counter;
    return [
      Text('가리고 쓰기', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      Text(
        _showExample
            ? '분홍색 예시와 내 글씨를 비교해 보세요.'
            : widget.hiragana
                ? '표시된 힌트에 해당하는 히라가나를 써보세요.'
                : koreanHint
                    ? '표시된 힌트에 해당하는 가타카나를 써보세요.'
                    : '히라가나를 보고 대응하는 가타카나를 써보세요.',
      ),
      const SizedBox(height: AppSizes.sm),
      Text(
        _letter.reading,
        locale: Locale(koreanHint ? 'ko' : 'ja'),
        style: theme.textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSizes.md),
      KatakanaRecallPad(
        key: ValueKey(_writingAttempt),
        onInkChanged: (hasInk) => setState(() => _hasInk = hasInk),
        initialStrokes: _strokes,
        onStrokesChanged: _inkChanged,
        enabled: _canInteract,
        example: _showExample ? _letter : null,
      ),
      const SizedBox(height: AppSizes.md),
      if (_showExample) ...[
        FilledButton(
          onPressed: _canInteract ? () => _goTo(_Step.word) : null,
          child: Text('${_letter.exampleKind.label}에서 찾기'),
        ),
        TextButton(
          onPressed: _canInteract ? () => _showComparison(false) : null,
          child: const Text('다시 써보기'),
        ),
      ] else ...[
        FilledButton(
          onPressed:
              _hasInk && _canInteract ? () => _showComparison(true) : null,
          child: const Text('예시와 비교'),
        ),
        TextButton(
          onPressed: _canInteract ? () => _goTo(_Step.word) : null,
          child: const Text('쓰기 건너뛰기'),
        ),
      ],
    ];
  }

  List<Widget> _wordContent(
    ThemeData theme,
    Set<KanaPracticeLetter>? marked,
    bool loadFailed,
  ) {
    final letter = _letter;
    final word = _dailyReview ? letter.reviewWord.text : letter.word;
    final reading =
        _dailyReview ? letter.reviewWord.reading : letter.wordReading;
    final meaning = _dailyReview ? letter.reviewWord.meaning : letter.meaning;
    final wordLabel = word == reading ? word : '$word ($reading)';
    final exampleKind = letter.exampleKind;
    final glyphs = word.runes.map(String.fromCharCode).toList();
    final selection = _selectedIndex;
    final correct = selection != null && glyphs[selection] == letter.glyph;
    final saved = marked?.contains(letter) ?? false;

    return [
      Text('${exampleKind.label}에서 찾기', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      Text(
          '이 ${exampleKind.contextLabel}에서 ‘${letter.reading}’에 해당하는 글자를 눌러보세요.'),
      const SizedBox(height: AppSizes.lg),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        children: [
          for (final (index, glyph) in glyphs.indexed)
            OutlinedButton(
              key: ValueKey('katakana-word-character-$index'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(52, 56),
                padding: const EdgeInsets.all(AppSizes.sm),
                backgroundColor: index == selection
                    ? theme.colorScheme.primaryContainer
                    : null,
                disabledBackgroundColor: index == selection && correct
                    ? theme.colorScheme.primaryContainer
                    : null,
                disabledForegroundColor:
                    correct ? theme.colorScheme.onSurface : null,
              ),
              onPressed:
                  correct || !_canActOnWord ? null : () => _selectWord(index),
              child: Text(
                glyph,
                locale: const Locale('ja'),
                style: theme.textTheme.headlineSmall,
              ),
            ),
        ],
      ),
      if (selection != null) ...[
        const SizedBox(height: AppSizes.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            correct
                ? '맞았어요! $wordLabel · $meaning'
                : '다시 찾아보세요. ‘${letter.reading}’에 해당하는 글자예요.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (loadFailed)
          _reviewRetry()
        else
          OutlinedButton(
            onPressed: marked == null || !_canActOnWord
                ? null
                : () => _save((review) => review.setMarked(letter, !saved)),
            child: Text(saved ? '헷갈림 표시 지우기' : '헷갈렸어요'),
          ),
        if (saved)
          Semantics(
            liveRegion: true,
            child: const Text('다음 복습에 저장했어요.'),
          ),
        if (_saveError != null)
          Semantics(
            liveRegion: true,
            child: Text(_saveError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: AppSizes.md),
        if (correct)
          FilledButton(
            onPressed: _canActOnWord ? _next : null,
            child: Text(_index + 1 == _letters.length ? '연습 마치기' : '다음 글자'),
          ),
      ],
    ];
  }

  Widget _reviewRetry() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('기기에서 복습 기록을 불러오지 못했어요.'),
          TextButton(
            onPressed: () => ref.invalidate(katakanaPilotReviewProvider),
            child: const Text('복습 기록 다시 불러오기'),
          ),
        ],
      );
}
