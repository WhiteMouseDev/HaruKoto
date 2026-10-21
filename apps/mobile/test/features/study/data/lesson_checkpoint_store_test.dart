import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lesson_resume_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('existing auth/preferences keys and another account are preserved',
      () async {
    SharedPreferences.setMockInitialValues(
        {'auth-fixture': 'unchanged', 'show_kana': true});
    final preferences = await SharedPreferences.getInstance();
    final store = PreferencesLessonCheckpointStore(preferences);
    await store.write('account-a', 'lesson', 'a');
    await store.write('account-b', 'lesson', 'b');
    await store.remove('account-a', 'lesson');
    expect(await store.read('account-b', 'lesson'), 'b');
    expect(await store.read('account-a', 'lesson'), isNull);
    expect(preferences.getString('auth-fixture'), 'unchanged');
    expect(preferences.getBool('show_kana'), isTrue);
  });
  test('writes then removal then read use one queue', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = PreferencesLessonCheckpointStore(preferences);
    final first = store.write('a', 'lesson', 'older');
    final second = store.write('a', 'lesson', 'latest');
    final remove = store.remove('a', 'lesson');
    final read = store.read('a', 'lesson');
    await Future.wait([first, second, remove]);
    expect(await read, isNull);
  });
  test('all edits are queued globally before dispose and a new controller read',
      () async {
    final h = ResumeHarness();
    await h.initialize();
    h.store.writeGate = Completer<void>();
    h.controller.goToVocabLearning();
    h.controller.setVocabIndex(1);
    h.controller.setVocabIndex(2);
    h.dispose();
    final fresh = ResumeHarness(store: h.store);
    addTearDown(fresh.dispose);
    final reading = fresh.initialize();
    h.store.writeGate!.complete();
    await reading;
    expect(fresh.state.vocabIndex, 2);
  });
}
