class CallSettings {
  final int silenceDurationMs;
  final double aiResponseSpeed;
  final bool subtitleEnabled;
  final bool autoAnalysis;

  const CallSettings({
    this.silenceDurationMs = 1200,
    this.aiResponseSpeed = 1.0,
    this.subtitleEnabled = true,
    this.autoAnalysis = true,
  });

  CallSettings copyWith({
    int? silenceDurationMs,
    double? aiResponseSpeed,
    bool? subtitleEnabled,
    bool? autoAnalysis,
  }) {
    return CallSettings(
      silenceDurationMs: silenceDurationMs ?? this.silenceDurationMs,
      aiResponseSpeed: aiResponseSpeed ?? this.aiResponseSpeed,
      subtitleEnabled: subtitleEnabled ?? this.subtitleEnabled,
      autoAnalysis: autoAnalysis ?? this.autoAnalysis,
    );
  }

  factory CallSettings.fromJson(Map<String, dynamic> json) {
    return CallSettings(
      silenceDurationMs: json['silenceDurationMs'] as int? ?? 1200,
      aiResponseSpeed: (json['aiResponseSpeed'] as num?)?.toDouble() ?? 1.0,
      subtitleEnabled: json['subtitleEnabled'] as bool? ?? true,
      autoAnalysis: json['autoAnalysis'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'silenceDurationMs': silenceDurationMs,
        'aiResponseSpeed': aiResponseSpeed,
        'subtitleEnabled': subtitleEnabled,
        'autoAnalysis': autoAnalysis,
      };
}
