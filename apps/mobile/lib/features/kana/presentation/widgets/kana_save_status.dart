import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';

String kanaSaveErrorMessage(Object error) {
  if (error is ApiException) return error.userMessage;
  if (error is DioException) {
    return ApiException.fromDioException(error).userMessage;
  }
  return const ApiException(
    message: '저장 상태를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
  ).userMessage;
}

/// Status for one pending operation. A retry repeats that operation only.
class KanaSaveStatus extends StatelessWidget {
  const KanaSaveStatus({
    super.key,
    required this.label,
    this.error,
    this.onRetry,
    this.retryLabel = '다시 시도',
  });

  final String label;
  final String? error;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error == null) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
            ],
            Text(label, textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
