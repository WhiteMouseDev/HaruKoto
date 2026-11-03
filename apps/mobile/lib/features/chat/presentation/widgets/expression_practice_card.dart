import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../study/presentation/wordbook_page.dart';
import '../../providers/conversation_expression_service.dart';

class ExpressionPracticeCard extends ConsumerStatefulWidget {
  const ExpressionPracticeCard(
      {super.key, required this.expression, required this.meaning});

  final String expression;
  final String meaning;

  @override
  ConsumerState<ExpressionPracticeCard> createState() =>
      _ExpressionPracticeCardState();
}

class _ExpressionPracticeCardState
    extends ConsumerState<ExpressionPracticeCard> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final inserted =
          await ref.read(conversationExpressionServiceProvider).save(
                expression: widget.expression,
                meaning: widget.meaning,
              );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(inserted ? '단어장에 표현을 저장했어요' : '이미 단어장에 있는 표현이에요'),
      ));
    } catch (error) {
      if (!mounted) return;
      final exception = error is ApiException
          ? error
          : error is DioException
              ? ApiException.fromDioException(error)
              : const ApiException(message: '표현을 저장하지 못했어요. 다시 시도해 주세요.');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(exception.userMessage)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('기억할 표현 하나', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.sm),
            Text(widget.expression,
                style: Theme.of(context).textTheme.titleLarge),
            if (widget.meaning.isNotEmpty) Text(widget.meaning),
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _RecallSheet(
                        expression: widget.expression, meaning: widget.meaning),
                  ),
                  icon: const Icon(LucideIcons.messageSquare, size: 16),
                  label: const Text('혼자 다시 말해보기'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _saved ? null : _save,
                  icon: Icon(_saved ? LucideIcons.check : LucideIcons.bookmark,
                      size: 16),
                  label: Text(_saving
                      ? '저장 중…'
                      : _saved
                          ? '저장된 표현'
                          : '단어장에 표현 저장'),
                ),
              ],
            ),
            if (_saved)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const WordbookPage())),
                child: const Text('단어장에서 보기'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecallSheet extends StatefulWidget {
  const _RecallSheet({required this.expression, required this.meaning});
  final String expression;
  final String meaning;

  @override
  State<_RecallSheet> createState() => _RecallSheetState();
}

class _RecallSheetState extends State<_RecallSheet> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('표현을 보지 않고 말해볼까요?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSizes.md),
            Text(widget.meaning.isEmpty
                ? '방금 본 표현을 떠올려 말해보세요.'
                : widget.meaning),
            const SizedBox(height: AppSizes.md),
            if (_revealed)
              Text(widget.expression,
                  style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSizes.md),
            const Text('마이크를 켜거나 녹음하지 않아요. 표현을 펼쳐 스스로 확인하는 연습이에요.'),
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: () => setState(() => _revealed = !_revealed),
              child: Text(_revealed ? '다시 가리고 연습' : '표현 펼쳐서 확인'),
            ),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('마치기')),
          ],
        ),
      ),
    );
  }
}
