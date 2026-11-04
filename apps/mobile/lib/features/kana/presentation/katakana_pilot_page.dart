import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/network/api_exception.dart';
import '../domain/katakana_pilot.dart';
import '../providers/katakana_pilot_review_provider.dart';
import 'widgets/katakana_pilot_strokes.dart';

class KatakanaPilotPage extends ConsumerWidget {
  const KatakanaPilotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('가타카나 집중 연습')),
      body: SafeArea(
        child: account == null
            ? const Center(child: Text('로그인 후 가타카나를 연습해 보세요.'))
            : _PilotSession(key: ValueKey(account), owner: account),
      ),
    );
  }
}

enum _Step { compare, recall, word }

class _PilotSession extends ConsumerStatefulWidget {
  const _PilotSession({super.key, required this.owner});

  final String owner;

  @override
  ConsumerState<_PilotSession> createState() => _PilotSessionState();
}

class _PilotSessionState extends ConsumerState<_PilotSession> {
  List<KatakanaPilotLetter> _letters = const [];
  int _index = 0;
  _Step _step = _Step.compare;
  int _writingAttempt = 0;
  bool _hasInk = false;
  bool _showExample = false;
  int? _selectedIndex;
  bool _saving = false;
  String? _saveError;

  KatakanaPilotLetter get _letter => _letters[_index];
  bool get _canActOnWord =>
      !_saving &&
      _step == _Step.word &&
      ref.read(currentAccountReaderProvider)() == widget.owner;

  void _start(List<KatakanaPilotLetter> letters) {
    setState(() {
      _letters = letters;
      _index = 0;
      _resetLetter();
    });
  }

  void _resetLetter() {
    _step = _Step.compare;
    _hasInk = false;
    _showExample = false;
    _selectedIndex = null;
    _saveError = null;
  }

  void _next() {
    if (!_canActOnWord) return;
    setState(() {
      if (_index + 1 == _letters.length) {
        _letters = const [];
        _index = 0;
      } else {
        _index++;
      }
      _resetLetter();
    });
  }

  Future<void> _setMarked(bool marked) async {
    if (!_canActOnWord) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(katakanaPilotReviewProvider.notifier).setMarked(
            _letter,
            marked,
          );
    } on ApiException catch (error) {
      if (mounted) setState(() => _saveError = error.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(katakanaPilotReviewProvider);
    final marked =
        review.isLoading || review.hasError ? null : review.asData?.value;
    final theme = Theme.of(context);
    final isStart = _letters.isEmpty;

    return ListView(
      key: ValueKey((isStart, _index, _step)),
      padding: const EdgeInsets.all(AppSizes.md),
      children: isStart
          ? _startContent(theme, marked, review.hasError)
          : [
              Text(
                '${_index + 1}/${_letters.length} 글자 · ${_step.index + 1}/3 단계',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSizes.sm),
              ...switch (_step) {
                _Step.compare => _compareContent(theme),
                _Step.recall => _recallContent(theme),
                _Step.word => _wordContent(theme, marked, review.hasError),
              },
            ],
    );
  }

  List<Widget> _startContent(
    ThemeData theme,
    Set<KatakanaPilotLetter>? marked,
    bool loadFailed,
  ) {
    final reviewLetters = KatakanaPilotLetter.values
        .where((letter) => marked?.contains(letter) ?? false)
        .toList();
    return [
      Text('닮은 글자, 어떻게 다를까요?', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      const Text('획순을 비교하고, 본보기를 가려 써본 뒤, 단어에서 같은 글자를 찾아보세요.'),
      const SizedBox(height: AppSizes.lg),
      Text('묶음 골라 연습', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSizes.sm),
      for (final group in KatakanaPracticeGroup.values) ...[
        FilledButton.tonal(
          key: ValueKey('katakana-practice-group-${group.name}'),
          onPressed: () => _start(group.letters),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          ),
          child: Text(
            group.label,
            locale: const Locale('ja'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
      ],
      const SizedBox(height: AppSizes.md),
      Text('이 기기에 저장된 복습', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSizes.sm),
      if (loadFailed)
        _reviewRetry()
      else if (marked == null)
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
        OutlinedButton(
          onPressed: () => _start(reviewLetters),
          child: const Text('헷갈린 글자 복습'),
        ),
      ],
    ];
  }

  List<Widget> _compareContent(ThemeData theme) => [
        Text('획순 비교', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSizes.sm),
        const Text('번호와 선으로 각 획의 시작점을 확인하세요. 획의 수와 위치, 그리는 방향을 비교해 보세요.'),
        const SizedBox(height: AppSizes.md),
        KatakanaStrokeComparison(letter: _letter),
        const SizedBox(height: AppSizes.md),
        FilledButton(
          onPressed: () => setState(() => _step = _Step.recall),
          child: const Text('가리고 쓰기'),
        ),
      ];

  List<Widget> _recallContent(ThemeData theme) => [
        Text('가리고 쓰기', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSizes.sm),
        Text(
          _showExample ? '분홍색 예시와 내 글씨를 비교해 보세요.' : '히라가나를 보고 대응하는 가타카나를 써보세요.',
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          _letter.reading,
          locale: const Locale('ja'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSizes.md),
        KatakanaRecallPad(
          key: ValueKey(_writingAttempt),
          onInkChanged: (hasInk) => setState(() => _hasInk = hasInk),
          example: _showExample ? _letter.strokes : null,
        ),
        const SizedBox(height: AppSizes.md),
        if (_showExample) ...[
          FilledButton(
            onPressed: () => setState(() => _step = _Step.word),
            child: const Text('단어에서 찾기'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _hasInk = false;
                _showExample = false;
                _writingAttempt++;
              });
            },
            child: const Text('다시 써보기'),
          ),
        ] else ...[
          FilledButton(
            onPressed:
                _hasInk ? () => setState(() => _showExample = true) : null,
            child: const Text('예시와 비교'),
          ),
          TextButton(
            onPressed: () => setState(() => _step = _Step.word),
            child: const Text('쓰기 건너뛰기'),
          ),
        ],
      ];

  List<Widget> _wordContent(
    ThemeData theme,
    Set<KatakanaPilotLetter>? marked,
    bool loadFailed,
  ) {
    final letter = _letter;
    final glyphs = letter.word.runes.map(String.fromCharCode).toList();
    final selection = _selectedIndex;
    final correct = selection != null && glyphs[selection] == letter.glyph;
    final saved = marked?.contains(letter) ?? false;

    return [
      Text('단어에서 찾기', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSizes.sm),
      Text('이 단어에서 ‘${letter.reading}’에 해당하는 글자를 눌러보세요.'),
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
                  correct ? null : () => setState(() => _selectedIndex = index),
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
                ? '맞았어요! ${letter.word} (${letter.wordReading}) · ${letter.meaning}'
                : '다시 찾아보세요. ‘${letter.reading}’에 해당하는 글자예요.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (loadFailed)
          _reviewRetry()
        else
          OutlinedButton(
            onPressed:
                marked == null || _saving ? null : () => _setMarked(!saved),
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
            onPressed: _saving ? null : _next,
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
