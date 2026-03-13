class PaymentModel {
  final String id;
  final String plan;
  final int amount;
  final String status;
  final String? paidAt;
  final String? createdAt;

  const PaymentModel({
    required this.id,
    required this.plan,
    required this.amount,
    required this.status,
    this.paidAt,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      plan: json['plan'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      paidAt: json['paidAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  String? get displayDate => paidAt ?? createdAt;
}
