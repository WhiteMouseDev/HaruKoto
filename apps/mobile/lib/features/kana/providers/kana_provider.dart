import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/kana_repository.dart';
import '../data/models/kana_character_model.dart';
import '../data/models/kana_progress_model.dart';
import '../data/models/kana_stage_model.dart';

final kanaRepositoryProvider = Provider((ref) {
  return KanaRepository(ref.watch(dioProvider));
});

final kanaProgressProvider =
    FutureProvider.autoDispose<KanaProgressModel>((ref) {
  return ref.watch(kanaRepositoryProvider).fetchProgress();
});

final kanaStagesProvider =
    FutureProvider.autoDispose.family<List<KanaStageModel>, String>(
        (ref, type) {
  return ref.watch(kanaRepositoryProvider).fetchStages(type);
});

final kanaCharactersProvider = FutureProvider.autoDispose
    .family<List<KanaCharacterModel>, String>((ref, type) {
  return ref.watch(kanaRepositoryProvider).fetchCharacters(type);
});

final kanaBasicCharactersProvider = FutureProvider.autoDispose
    .family<List<KanaCharacterModel>, String>((ref, type) {
  return ref
      .watch(kanaRepositoryProvider)
      .fetchCharacters(type, category: 'basic');
});
