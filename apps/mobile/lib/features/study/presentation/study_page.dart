import 'package:flutter/material.dart';

class StudyPage extends StatelessWidget {
  const StudyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: const Center(
        child: Text('학습 페이지 (Phase 1에서 구현)'),
      ),
    );
  }
}
