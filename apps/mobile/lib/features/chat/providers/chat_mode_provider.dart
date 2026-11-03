import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shared_preferences_provider.dart';

class ChatModeController extends Notifier<int> {
  static const _key = 'chat_last_mode';

  @override
  int build() =>
      (ref.read(sharedPreferencesProvider).getInt(_key) ?? 0).clamp(0, 1);

  Future<void> select(int index) async {
    if (index == state) return;
    state = index.clamp(0, 1);
    await ref.read(sharedPreferencesProvider).setInt(_key, state);
  }
}

final chatModeProvider =
    NotifierProvider<ChatModeController, int>(ChatModeController.new);
