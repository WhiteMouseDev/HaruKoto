class PaymentRecord {
  final String id;
  final String plan;
  final int amount;
  final String status;
  final String? paidAt;
  final String createdAt;

  const PaymentRecord({
    required this.id,
    required this.plan,
    required this.amount,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String? ?? '',
      plan: json['plan'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      paidAt: json['paidAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
