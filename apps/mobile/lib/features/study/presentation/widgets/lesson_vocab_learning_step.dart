import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_learning_card.dart';
import 'lesson_stage_actions.dart';

class LessonVocabLearningStep extends StatefulWidget {
  final List<VocabItemModel> vocabItems;
  final VoidCallback onNext;
  final VoidCallback? onBackToPrev;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  const LessonVocabLearningStep({
    super.key,
    required this.vocabItems,
    required this.onNext,
    this.onBackToPrev,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  @override
  State<LessonVocabLearningStep> createState() =>
      _LessonVocabLearningStepState();
}

class _LessonVocabLearningStepState extends State<LessonVocabLearningStep> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  List<VocabItemModel> get _uniqueVocab {
    final seen = <String>{};
    return widget.vocabItems.where((vocab) {
      final key = '${vocab.word}_${vocab.reading}';
      return seen.add(key);
    }).toList();
  }

  String _partOfSpeechLabel(String value) {
    switch (value.trim().toUpperCase()) {
      case 'NOUN':
        return '명사';
      case 'VERB':
        return '동사';
      case 'ADJECTIVE':
        return '형용사';
      case 'I_ADJECTIVE':
        return '이형용사';
      case 'NA_ADJECTIVE':
        return '나형용사';
      case 'ADVERB':
        return '부사';
      case 'PRONOUN':
        return '대명사';
      case 'PARTICLE':
        return '조사';
      case 'EXPRESSION':
        return '표현';
      case 'PHRASE':
        return '구문';
      case 'INTERJECTION':
        return '감탄사';
      case 'CONJUNCTION':
        return '접속사';
      default:
        return value;
    }
  }

  @override
  void didUpdateWidget(LessonVocabLearningStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index);
    widget.onIndexChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final vocab = _uniqueVocab;
    if (vocab.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.vocabItems.isEmpty) widget.onNext();
      });
      return const SizedBox.shrink();
    }

    final index = _currentIndex.clamp(0, vocab.length - 1);
    final item = vocab[index];
    final isLast = index == vocab.length - 1;
    final reading = item.reading.trim();
    final partOfSpeech = item.partOfSpeech.trim();
    final vocabId = item.id.trim();
    final pronunciation = reading.isNotEmpty ? reading : item.word.trim();

    return Column(
      children: [
        Expanded(
          child: LessonLearningCard(
            itemType: '단어',
            itemIndex: index,
            itemCount: vocab.length,
            term: item.word,
            meaning: item.meaningKo,
            reading: reading.isNotEmpty && reading != item.word.trim()
                ? reading
                : null,
            partOfSpeech: partOfSpeech.isNotEmpty
                ? _partOfSpeechLabel(partOfSpeech)
                : null,
            audio: vocabId.isEmpty && pronunciation.isEmpty
                ? null
                : TtsPlayButton(
                    vocabId: vocabId.isEmpty ? null : vocabId,
                    text: vocabId.isEmpty ? pronunciation : null,
                    iconColor: AppColors.brandPink,
                  ),
            onPrevious: index > 0 ? () => _goTo(index - 1) : null,
            onNext: isLast ? null : () => _goTo(index + 1),
          ),
        ),
        LessonStageActions(
          nextLabel: '다음학습',
          onPrevious: widget.onBackToPrev,
          onNext: isLast ? widget.onNext : null,
        ),
      ],
    );
  }
}
