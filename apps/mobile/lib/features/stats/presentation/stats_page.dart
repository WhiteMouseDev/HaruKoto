import 'package:flutter/material.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학습 통계')),
      body: const Center(
        child: Text('학습 통계 페이지 (Phase 1에서 구현)'),
      ),
    );
  }
}
