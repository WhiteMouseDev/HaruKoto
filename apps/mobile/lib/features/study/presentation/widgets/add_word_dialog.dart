import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../providers/study_provider.dart';

Future<void> showAddWordDialog(BuildContext context, WidgetRef ref,
    {VoidCallback? onAdded}) {
  final wordCtrl = TextEditingController();
  final readingCtrl = TextEditingController();
  final meaningCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('단어 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordCtrl,
                decoration: const InputDecoration(
                  labelText: '단어',
                  hintText: '例: 食べる',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: readingCtrl,
                decoration: const InputDecoration(
                  labelText: '읽기',
                  hintText: '例: たべる',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: meaningCtrl,
                decoration: const InputDecoration(
                  labelText: '뜻',
                  hintText: '例: 먹다',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              if (wordCtrl.text.isEmpty || meaningCtrl.text.isEmpty) return;
              final repo = ref.read(studyRepositoryProvider);
              try {
                await repo.addWord(
                  word: wordCtrl.text.trim(),
                  reading: readingCtrl.text.trim().isEmpty
                      ? wordCtrl.text.trim()
                      : readingCtrl.text.trim(),
                  meaningKo: meaningCtrl.text.trim(),
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                onAdded?.call();
              } catch (e, stackTrace) {
                unawaited(Sentry.captureException(e, stackTrace: stackTrace));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('단어 추가에 실패했습니다')),
                  );
                }
              }
            },
            child: const Text('추가'),
          ),
        ],
      );
    },
  ).then((_) {
    wordCtrl.dispose();
    readingCtrl.dispose();
    meaningCtrl.dispose();
    noteCtrl.dispose();
  });
}
