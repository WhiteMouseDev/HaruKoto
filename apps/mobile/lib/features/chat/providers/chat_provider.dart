import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/chat_repository.dart';
import '../data/models/scenario_model.dart';
import '../data/models/character_model.dart';
import '../data/models/conversation_model.dart';

final chatRepositoryProvider = Provider((ref) {
  return ChatRepository(ref.watch(dioProvider));
});

final scenariosProvider =
    FutureProvider.autoDispose.family<List<ScenarioModel>, String>(
  (ref, category) {
    return ref.watch(chatRepositoryProvider).fetchScenarios(category: category);
  },
);

final chatHistoryProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final page = await ref.watch(chatRepositoryProvider).fetchHistory();
  return page.history;
});

final charactersProvider =
    FutureProvider.autoDispose<List<CharacterListItem>>((ref) {
  return ref.watch(chatRepositoryProvider).fetchCharacters();
});

final characterStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(chatRepositoryProvider).fetchCharacterStats();
});

final characterFavoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(chatRepositoryProvider).fetchCharacterFavorites();
});
