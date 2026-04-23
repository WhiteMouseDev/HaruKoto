enum SpecialQuizAnswerOutcome {
  answered,
  ignored,
}

enum SpecialQuizAdvanceOutcome {
  advanced,
  completed,
}

class SpecialQuizFlowController {
  SpecialQuizFlowController({int initialIndex = 0})
      : _currentIndex = initialIndex;

  int _currentIndex;
  bool _answered = false;
  bool _isCorrect = false;

  int get currentIndex => _currentIndex;
  bool get answered => _answered;
  bool get isCorrect => _isCorrect;

  double progressFor(int questionCount) {
    if (questionCount <= 0) return 0;
    return (_currentIndex + 1) / questionCount;
  }

  String countLabelFor(int questionCount) {
    if (questionCount <= 0) return '0/0';
    return '${_currentIndex + 1}/$questionCount';
  }

  bool isLastQuestion(int questionCount) {
    return _currentIndex + 1 >= questionCount;
  }

  SpecialQuizAnswerOutcome answer({required bool isCorrect}) {
    if (_answered) {
      return SpecialQuizAnswerOutcome.ignored;
    }

    _answered = true;
    _isCorrect = isCorrect;
    return SpecialQuizAnswerOutcome.answered;
  }

  SpecialQuizAdvanceOutcome advance(int questionCount) {
    if (isLastQuestion(questionCount)) {
      return SpecialQuizAdvanceOutcome.completed;
    }

    _currentIndex++;
    _answered = false;
    _isCorrect = false;
    return SpecialQuizAdvanceOutcome.advanced;
  }
}
