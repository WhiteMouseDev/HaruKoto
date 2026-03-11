import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회화')),
      body: const Center(
        child: Text('회화 페이지 (Phase 1에서 구현)'),
      ),
    );
  }
}
