import 'package:flutter/material.dart';

class QuizWrongAnswersStatus extends StatelessWidget {
  const QuizWrongAnswersStatus({
    super.key,
    required this.loading,
    required this.wrongCount,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final int wrongCount;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noWrongAnswers = !loading && error == null && wrongCount == 0;
    final title = loading
        ? '이번 퀴즈의 오답을 불러오고 있어요'
        : error != null
            ? '오답을 불러오지 못했어요'
            : noWrongAnswers
                ? '이번 퀴즈에는 오답이 없어요'
                : '표시할 오답이 없어요';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  noWrongAnswers
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          if (!loading && !noWrongAnswers) ...[
            const SizedBox(height: 8),
            Text(
              error ?? '오답 목록을 다시 불러와 주세요.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 불러오기'),
            ),
          ],
        ],
      ),
    );
  }
}
