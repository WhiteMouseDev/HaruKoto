class StageModel {
  final String id;
  final int stageNumber;
  final String title;
  final String? description;
  final int contentCount;
  final bool isLocked;
  final StageProgress? userProgress;

  const StageModel({
    required this.id,
    required this.stageNumber,
    required this.title,
    this.description,
    required this.contentCount,
    required this.isLocked,
    this.userProgress,
  });

  bool get isCompleted => userProgress?.completed ?? false;

  int get bestScore => userProgress?.bestScore ?? 0;

  factory StageModel.fromJson(Map<String, dynamic> json) {
    return StageModel(
      id: json['id'] as String,
      stageNumber: json['stageNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      contentCount: json['contentCount'] as int? ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      userProgress: json['userProgress'] != null
          ? StageProgress.fromJson(
              json['userProgress'] as Map<String, dynamic>)
          : null,
    );
  }
}

class StageProgress {
  final int bestScore;
  final int attempts;
  final bool completed;

  const StageProgress({
    required this.bestScore,
    required this.attempts,
    required this.completed,
  });

  factory StageProgress.fromJson(Map<String, dynamic> json) {
    return StageProgress(
      bestScore: json['bestScore'] as int? ?? 0,
      attempts: json['attempts'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
