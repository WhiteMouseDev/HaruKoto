class SmartPreviewModel {
  final PoolSize poolSize;
  final SessionDistribution sessionDistribution;
  final int dailyGoal;
  final int todayCompleted;
  final OverallProgress overallProgress;

  SmartPreviewModel({
    required this.poolSize,
    required this.sessionDistribution,
    required this.dailyGoal,
    required this.todayCompleted,
    required this.overallProgress,
  });

  factory SmartPreviewModel.fromJson(Map<String, dynamic> json) {
    return SmartPreviewModel(
      poolSize: PoolSize.fromJson(json['poolSize'] as Map<String, dynamic>),
      sessionDistribution: SessionDistribution.fromJson(
        json['sessionDistribution'] as Map<String, dynamic>,
      ),
      dailyGoal: json['dailyGoal'] as int,
      todayCompleted: json['todayCompleted'] as int,
      overallProgress: OverallProgress.fromJson(
        json['overallProgress'] as Map<String, dynamic>,
      ),
    );
  }
}

class PoolSize {
  final int newReady;
  final int reviewDue;
  final int retryDue;

  PoolSize({
    required this.newReady,
    required this.reviewDue,
    required this.retryDue,
  });

  factory PoolSize.fromJson(Map<String, dynamic> json) {
    return PoolSize(
      newReady: json['newReady'] as int,
      reviewDue: json['reviewDue'] as int,
      retryDue: json['retryDue'] as int,
    );
  }
}

class SessionDistribution {
  final int newCount;
  final int review;
  final int retry;
  final int total;

  SessionDistribution({
    required this.newCount,
    required this.review,
    required this.retry,
    required this.total,
  });

  factory SessionDistribution.fromJson(Map<String, dynamic> json) {
    return SessionDistribution(
      newCount: json['new'] as int,
      review: json['review'] as int,
      retry: json['retry'] as int,
      total: json['total'] as int,
    );
  }
}

class OverallProgress {
  final int total;
  final int studied;
  final int mastered;
  final int percentage;

  OverallProgress({
    required this.total,
    required this.studied,
    required this.mastered,
    required this.percentage,
  });

  factory OverallProgress.fromJson(Map<String, dynamic> json) {
    return OverallProgress(
      total: json['total'] as int,
      studied: json['studied'] as int,
      mastered: json['mastered'] as int,
      percentage: json['percentage'] as int,
    );
  }
}
