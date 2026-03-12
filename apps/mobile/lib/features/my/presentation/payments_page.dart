import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/my_provider.dart';

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  int _page = 1;
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(myRepositoryProvider).fetchPayments(_page);
      if (!mounted) return;
      setState(() {
        _payments = (data['payments'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _totalPages = data['totalPages'] as int? ?? 1;
        _loading = false;
      });
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final date = DateTime.tryParse(iso);
    if (date == null) return '-';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  String _formatPrice(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'monthly':
        return '월간 프리미엄';
      case 'yearly':
        return '연간 프리미엄';
      default:
        return plan;
    }
  }

  (String, Color) _statusInfo(String status, Brightness brightness) {
    switch (status) {
      case 'paid':
        return ('결제 완료', AppColors.success(brightness));
      case 'pending':
        return ('대기 중', AppColors.info(brightness));
      case 'failed':
        return ('실패', AppColors.error(brightness));
      case 'refunded':
        return ('환불', AppColors.warning(brightness));
      case 'cancelled':
        return ('취소', AppColors.warning(brightness));
      default:
        return (status, AppColors.info(brightness));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(title: const Text('결제 내역')),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: List.generate(3, (_) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    ),
                  ),
                );
              }),
            )
          : _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.creditCard,
                        size: 40,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '결제 내역이 없습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.md),
                  children: [
                    ..._payments.map((p) {
                      final status = _statusInfo(p['status'] as String? ?? '', brightness);
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.cardRadius),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _planLabel(p['plan'] as String? ?? ''),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(
                                      (p['paidAt'] ?? p['createdAt'])
                                          as String?,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_formatPrice(p['amount'] as int? ?? 0)}원',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: status.$2.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.$1,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: status.$2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Pagination
                    if (_totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _page > 1
                                  ? () {
                                      setState(() => _page--);
                                      _fetchPayments();
                                    }
                                  : null,
                              icon: const Icon(LucideIcons.chevronLeft, size: 16),
                            ),
                            Text(
                              '$_page / $_totalPages',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            IconButton(
                              onPressed: _page < _totalPages
                                  ? () {
                                      setState(() => _page++);
                                      _fetchPayments();
                                    }
                                  : null,
                              icon: const Icon(LucideIcons.chevronRight, size: 16),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
