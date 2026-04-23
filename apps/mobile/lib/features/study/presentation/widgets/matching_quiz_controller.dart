import 'dart:math';

import '../../data/models/quiz_question_model.dart';

enum MatchingQuizRoundOutcome {
  inProgress,
  advanced,
  completed,
}

class MatchingQuizAttemptResult {
  const MatchingQuizAttemptResult({
    required this.leftPair,
    required this.rightPair,
    required this.isCorrect,
  });

  final MatchingQuizPair leftPair;
  final MatchingQuizPair rightPair;
  final bool isCorrect;
}

class MatchingQuizController {
  MatchingQuizController({
    required List<MatchingQuizPair> pairs,
    int pairsPerRound = 5,
    Random? random,
  })  : _allPairs = List.unmodifiable(pairs),
        _pairsPerRound = _normalizePairsPerRound(pairsPerRound),
        _random = random ?? Random() {
    _startRound();
  }

  final List<MatchingQuizPair> _allPairs;
  final int _pairsPerRound;
  final Random _random;

  int _roundIndex = 0;
  int _totalCorrect = 0;
  var _currentPairs = <MatchingQuizPair>[];
  var _shuffledRightPairs = <MatchingQuizPair>[];
  final _matchedIds = <String>{};
  String? _selectedLeftId;
  String? _selectedRightId;
  bool _isResolving = false;

  int get roundIndex => _roundIndex;
  int get totalCorrect => _totalCorrect;
  int get totalCount => _allPairs.length;
  int get totalRounds =>
      _allPairs.isEmpty ? 0 : (_allPairs.length / _pairsPerRound).ceil();
  bool get hasMultipleRounds => totalRounds > 1;
  bool get isResolving => _isResolving;
  String get scoreLabel => '$_totalCorrect/${_allPairs.length} 맞춤';
  String get roundLabel => '라운드 ${_roundIndex + 1}/$totalRounds';

  List<MatchingQuizPair> get currentPairs => List.unmodifiable(_currentPairs);

  List<MatchingQuizPair> get unmatchedLeftPairs => List.unmodifiable(
        _currentPairs.where((pair) => !_matchedIds.contains(pair.id)),
      );

  List<MatchingQuizPair> get unmatchedRightPairs => List.unmodifiable(
        _shuffledRightPairs.where((pair) => !_matchedIds.contains(pair.id)),
      );

  bool isLeftSelected(String pairId) => _selectedLeftId == pairId;

  bool isRightSelected(String pairId) => _selectedRightId == pairId;

  MatchingQuizAttemptResult? selectLeft(String pairId) {
    if (!_canSelect(pairId)) return null;
    _selectedLeftId = pairId;
    return _resolveIfReady();
  }

  MatchingQuizAttemptResult? selectRight(String pairId) {
    if (!_canSelect(pairId)) return null;
    _selectedRightId = pairId;
    return _resolveIfReady();
  }

  MatchingQuizRoundOutcome finishAttempt() {
    _selectedLeftId = null;
    _selectedRightId = null;
    _isResolving = false;

    if (_currentPairs.isEmpty || _matchedIds.length < _currentPairs.length) {
      return MatchingQuizRoundOutcome.inProgress;
    }

    if (_roundIndex + 1 < totalRounds) {
      _roundIndex++;
      _startRound();
      return MatchingQuizRoundOutcome.advanced;
    }

    return MatchingQuizRoundOutcome.completed;
  }

  void _startRound() {
    final start = _roundIndex * _pairsPerRound;
    final end = min(start + _pairsPerRound, _allPairs.length);
    _currentPairs = _allPairs.sublist(start, end);
    _shuffledRightPairs = List.of(_currentPairs)..shuffle(_random);
    _matchedIds.clear();
    _selectedLeftId = null;
    _selectedRightId = null;
    _isResolving = false;
  }

  bool _canSelect(String pairId) {
    if (_isResolving || _matchedIds.contains(pairId)) return false;
    return _currentPairs.any((pair) => pair.id == pairId);
  }

  MatchingQuizAttemptResult? _resolveIfReady() {
    final selectedLeftId = _selectedLeftId;
    final selectedRightId = _selectedRightId;
    if (selectedLeftId == null || selectedRightId == null) return null;

    final leftPair = _currentPairById(selectedLeftId);
    final rightPair = _currentPairById(selectedRightId);
    if (leftPair == null || rightPair == null) return null;

    final isCorrect = leftPair.id == rightPair.id;
    if (isCorrect) {
      _totalCorrect++;
      _matchedIds.add(leftPair.id);
    }

    _isResolving = true;
    return MatchingQuizAttemptResult(
      leftPair: leftPair,
      rightPair: rightPair,
      isCorrect: isCorrect,
    );
  }

  MatchingQuizPair? _currentPairById(String pairId) {
    for (final pair in _currentPairs) {
      if (pair.id == pairId) return pair;
    }
    return null;
  }

  static int _normalizePairsPerRound(int pairsPerRound) {
    if (pairsPerRound < 1) {
      throw ArgumentError.value(
        pairsPerRound,
        'pairsPerRound',
        'must be greater than zero',
      );
    }
    return pairsPerRound;
  }
}

class MatchingQuizPair {
  const MatchingQuizPair({
    required this.id,
    required this.left,
    this.reading,
    required this.right,
  });

  final String id;
  final String left;
  final String? reading;
  final String right;

  factory MatchingQuizPair.fromQuestion(QuizQuestionModel question) {
    final matchingWord = question.matchingWord;
    final matchingMeaning = question.matchingMeaning;

    if (matchingWord != null && matchingMeaning != null) {
      return MatchingQuizPair(
        id: question.questionId,
        left: matchingWord,
        reading: question.questionSubText,
        right: matchingMeaning,
      );
    }

    final correctOption = question.options.firstWhere(
      (option) => option.id == question.correctOptionId,
    );

    return MatchingQuizPair(
      id: question.questionId,
      left: question.questionText,
      reading: question.questionSubText,
      right: correctOption.text,
    );
  }
}
