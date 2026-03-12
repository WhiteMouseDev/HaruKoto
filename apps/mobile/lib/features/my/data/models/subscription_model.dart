class SubscriptionStatus {
  final SubscriptionInfo subscription;
  final AiUsage? aiUsage;

  const SubscriptionStatus({required this.subscription, this.aiUsage});

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      subscription: SubscriptionInfo.fromJson(
        json['subscription'] as Map<String, dynamic>? ?? {},
      ),
      aiUsage: json['aiUsage'] != null
          ? AiUsage.fromJson(json['aiUsage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SubscriptionInfo {
  final bool isPremium;
  final String plan;
  final String? expiresAt;
  final String? cancelledAt;

  const SubscriptionInfo({
    required this.isPremium,
    required this.plan,
    this.expiresAt,
    this.cancelledAt,
  });

  bool get isCancelled => cancelledAt != null;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      isPremium: json['isPremium'] as bool? ?? false,
      plan: json['plan'] as String? ?? 'FREE',
      expiresAt: json['expiresAt'] as String?,
      cancelledAt: json['cancelledAt'] as String?,
    );
  }
}

class AiUsage {
  final int chatCount;
  final int chatLimit;
  final int callCount;
  final int callLimit;
  final int chatSeconds;
  final int chatSecondsLimit;
  final int callSeconds;
  final int callSecondsLimit;

  const AiUsage({
    required this.chatCount,
    required this.chatLimit,
    required this.callCount,
    required this.callLimit,
    required this.chatSeconds,
    required this.chatSecondsLimit,
    required this.callSeconds,
    required this.callSecondsLimit,
  });

  factory AiUsage.fromJson(Map<String, dynamic> json) {
    return AiUsage(
      chatCount: json['chatCount'] as int? ?? 0,
      chatLimit: json['chatLimit'] as int? ?? 3,
      callCount: json['callCount'] as int? ?? 0,
      callLimit: json['callLimit'] as int? ?? 1,
      chatSeconds: json['chatSeconds'] as int? ?? 0,
      chatSecondsLimit: json['chatSecondsLimit'] as int? ?? 0,
      callSeconds: json['callSeconds'] as int? ?? 0,
      callSecondsLimit: json['callSecondsLimit'] as int? ?? 0,
    );
  }
}
