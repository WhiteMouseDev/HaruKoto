class MissionModel {
  final String id;
  final String missionType;
  final String label;
  final String description;
  final int targetCount;
  final int currentCount;
  final int xpReward;
  final bool isCompleted;
  final bool rewardClaimed;

  const MissionModel({
    required this.id,
    required this.missionType,
    required this.label,
    required this.description,
    required this.targetCount,
    required this.currentCount,
    required this.xpReward,
    required this.isCompleted,
    required this.rewardClaimed,
  });

  double get progress =>
      targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0.0;

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['id']?.toString() ?? '',
      missionType: json['missionType'] as String? ?? 'words',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      rewardClaimed: json['rewardClaimed'] as bool? ?? false,
    );
  }
}
