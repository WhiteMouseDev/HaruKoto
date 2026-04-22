class FreeQuizSelection {
  final String level;
  final String type;
  final String mode;

  const FreeQuizSelection({
    this.level = 'N5',
    this.type = 'VOCABULARY',
    this.mode = 'normal',
  });

  static const jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  static const quizTypes = [
    ('VOCABULARY', '단어'),
    ('GRAMMAR', '문법'),
  ];

  static const modeLabels = {
    'normal': '4지선다',
    'matching': '매칭',
    'cloze': '빈칸',
    'arrange': '어순',
  };

  String get contentLabel => type == 'VOCABULARY' ? '단어' : '문법';

  String get modeLabel => modeLabels[mode] ?? '4지선다';

  List<String> get availableModes {
    if (type == 'GRAMMAR') {
      return const ['normal', 'cloze', 'arrange'];
    }
    return const ['normal', 'matching', 'cloze', 'arrange'];
  }

  FreeQuizSelection copyWith({
    String? level,
    String? type,
    String? mode,
  }) {
    return FreeQuizSelection(
      level: level ?? this.level,
      type: type ?? this.type,
      mode: mode ?? this.mode,
    );
  }

  FreeQuizSelection selectType(String nextType) {
    final next = copyWith(type: nextType);
    if (next.availableModes.contains(next.mode)) {
      return next;
    }
    return next.copyWith(mode: 'normal');
  }
}
