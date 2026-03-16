class DashboardModel {
  final bool showKana;
  final TodayStats today;
  final StreakData streak;
  final List<WeeklyStatEntry> weeklyStats;
  final KanaProgressData? kanaProgress;
  final LevelProgressData? levelProgress;

  const DashboardModel({
    required this.showKana,
    required this.today,
    required this.streak,
    required this.weeklyStats,
    this.kanaProgress,
    this.levelProgress,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      showKana: json['showKana'] as bool? ?? false,
      today: TodayStats.fromJson(json['today'] as Map<String, dynamic>? ?? {}),
      streak:
          StreakData.fromJson(json['streak'] as Map<String, dynamic>? ?? {}),
      weeklyStats: (json['weeklyStats'] as List<dynamic>?)
              ?.map((e) => WeeklyStatEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      kanaProgress: json['kanaProgress'] != null
          ? KanaProgressData.fromJson(
              json['kanaProgress'] as Map<String, dynamic>)
          : null,
      levelProgress: json['levelProgress'] != null
          ? LevelProgressData.fromJson(
              json['levelProgress'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TodayStats {
  final int wordsStudied;
  final int quizzesCompleted;
  final int correctAnswers;
  final int totalAnswers;
  final int xpEarned;
  final double goalProgress;

  const TodayStats({
    required this.wordsStudied,
    required this.quizzesCompleted,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.xpEarned,
    required this.goalProgress,
  });

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    return TodayStats(
      wordsStudied: json['wordsStudied'] as int? ?? 0,
      quizzesCompleted: json['quizzesCompleted'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      totalAnswers: json['totalAnswers'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
      goalProgress: (json['goalProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StreakData {
  final int current;
  final int longest;

  const StreakData({required this.current, required this.longest});

  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      current: json['current'] as int? ?? 0,
      longest: json['longest'] as int? ?? 0,
    );
  }
}

class WeeklyStatEntry {
  final String date;
  final int wordsStudied;
  final int xpEarned;

  const WeeklyStatEntry({
    required this.date,
    required this.wordsStudied,
    required this.xpEarned,
  });

  factory WeeklyStatEntry.fromJson(Map<String, dynamic> json) {
    return WeeklyStatEntry(
      date: json['date'] as String? ?? '',
      wordsStudied: json['wordsStudied'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
    );
  }
}

class KanaProgressData {
  final KanaStat hiragana;
  final KanaStat katakana;

  const KanaProgressData({
    required this.hiragana,
    required this.katakana,
  });

  bool get completed =>
      hiragana.total > 0 &&
      hiragana.learned >= hiragana.total &&
      katakana.total > 0 &&
      katakana.learned >= katakana.total;

  factory KanaProgressData.fromJson(Map<String, dynamic> json) {
    return KanaProgressData(
      hiragana:
          KanaStat.fromJson(json['hiragana'] as Map<String, dynamic>? ?? {}),
      katakana:
          KanaStat.fromJson(json['katakana'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class KanaStat {
  final int learned;
  final int total;
  final double pct;

  const KanaStat({
    required this.learned,
    required this.total,
    required this.pct,
  });

  factory KanaStat.fromJson(Map<String, dynamic> json) {
    return KanaStat(
      learned: json['learned'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      pct: (json['pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LevelProgressData {
  final ProgressStat vocabulary;
  final ProgressStat grammar;

  const LevelProgressData({
    required this.vocabulary,
    required this.grammar,
  });

  factory LevelProgressData.fromJson(Map<String, dynamic> json) {
    return LevelProgressData(
      vocabulary: ProgressStat.fromJson(
          json['vocabulary'] as Map<String, dynamic>? ?? {}),
      grammar:
          ProgressStat.fromJson(json['grammar'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ProgressStat {
  final int total;
  final int mastered;
  final int inProgress;

  const ProgressStat({
    required this.total,
    required this.mastered,
    required this.inProgress,
  });

  factory ProgressStat.fromJson(Map<String, dynamic> json) {
    return ProgressStat(
      total: json['total'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      inProgress: json['inProgress'] as int? ?? 0,
    );
  }
}
