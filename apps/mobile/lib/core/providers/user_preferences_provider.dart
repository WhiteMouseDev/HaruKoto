import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/current_account_provider.dart';
import '../network/api_exception.dart';
import '../settings/call_settings.dart';
import '../settings/user_preferences.dart';
import '../settings/user_preferences_repository.dart';
import 'shared_preferences_provider.dart';

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>(
  (ref) {
    return UserPreferencesRepository(
      sharedPreferences: ref.watch(sharedPreferencesProvider),
    );
  },
);

/// Captured before a request, so a delayed response cannot change a new account
/// or overwrite a goal edited since that request started.
class PreferencesRequestScope {
  const PreferencesRequestScope(this.owner, this.generation, this.goalRevision);
  final String? owner;
  final int generation;
  final int goalRevision;
}

class UserPreferencesNotifier extends Notifier<UserPreferences> {
  UserPreferencesRepository get _repository =>
      ref.read(userPreferencesRepositoryProvider);
  String? _owner;
  int _generation = 0;
  int _goalRevision = 0;
  bool _savingGoal = false;
  Future<void> _writes = Future.value();

  @override
  UserPreferences build() {
    _owner = ref.watch(currentAccountIdProvider);
    _generation++;
    _goalRevision++;
    _savingGoal = false;
    return _repository.load(accountId: _owner);
  }

  PreferencesRequestScope get requestScope =>
      PreferencesRequestScope(_owner, _generation, _goalRevision);

  bool isCurrent(PreferencesRequestScope scope) =>
      scope.goalRevision == _goalRevision && isCurrentAccount(scope);

  bool isCurrentAccount(PreferencesRequestScope scope) =>
      ref.mounted &&
      scope.owner == _owner &&
      scope.generation == _generation &&
      ref.read(currentAccountReaderProvider)() == _owner;

  Future<void> _persist(UserPreferences preferences) {
    final repository = _repository;
    final owner = _owner;
    final operation = _writes
        .catchError((Object _) {})
        .then((_) => repository.persist(preferences, accountId: owner));
    _writes = operation;
    return operation;
  }

  // Other setting updates must not restore a stale goal snapshot during a
  // concurrent goal save. Goal changes use the explicit begin/finish protocol.
  Future<void> replace(UserPreferences preferences) async {
    final next = preferences.copyWith(
      dailyGoal: state.dailyGoal,
      dailyGoalConfirmed: state.dailyGoalConfirmed,
    );
    state = next;
    await _persist(next);
  }

  Future<void> syncFromServer({
    required PreferencesRequestScope scope,
    bool? showFurigana,
    bool? showKana,
    int? dailyGoal,
    String? jlptLevel,
    CallSettings? callSettings,
  }) async {
    if (!isCurrent(scope) || _savingGoal) return;
    final validGoal = dailyGoal != null && dailyGoal >= 5 && dailyGoal <= 50;
    final next = state.copyWith(
      showFurigana: showFurigana,
      showKana: showKana,
      dailyGoal: validGoal ? dailyGoal : null,
      dailyGoalConfirmed: validGoal ? true : null,
      jlptLevel: jlptLevel,
      callSettings: callSettings,
    );
    state = next;
    await _persist(next);
  }

  Future<PreferencesRequestScope> beginDailyGoalUpdate(int value) async {
    if (_owner == null || ref.read(currentAccountReaderProvider)() != _owner) {
      throw const ApiException(message: '로그인한 계정의 목표를 다시 확인해주세요.');
    }
    if (value < 5 || value > 50) {
      throw const ApiException(message: '하루 목표는 5개에서 50개 사이로 설정해주세요.');
    }
    if (_savingGoal) throw StateError('A daily goal update is already pending');
    _goalRevision++;
    _savingGoal = true;
    state = state.copyWith(dailyGoal: value, dailyGoalConfirmed: false);
    // The optimistic goal is not a confirmed account cache and is not persisted.
    return requestScope;
  }

  Future<void> finishDailyGoalUpdate(PreferencesRequestScope scope,
      {required int value}) async {
    if (!isCurrent(scope)) return;
    _goalRevision++;
    _savingGoal = false;
    final next = state.copyWith(dailyGoal: value, dailyGoalConfirmed: true);
    state = next;
    await _persist(next);
  }

  void cancelDailyGoalUpdate(
      PreferencesRequestScope scope, UserPreferences previous) {
    if (!isCurrent(scope)) return;
    _goalRevision++;
    _savingGoal = false;
    state = state.copyWith(
      dailyGoal: previous.dailyGoal,
      dailyGoalConfirmed: previous.dailyGoalConfirmed,
    );
  }

  Future<void> setShowFurigana(bool value) =>
      replace(state.copyWith(showFurigana: value));
  Future<void> setShowKana(bool value) =>
      replace(state.copyWith(showKana: value));

  /// Local draft compatibility helper. Only a server-confirmed update can
  /// populate the account goal cache or produce a known percentage.
  Future<void> setDailyGoal(int value) async {
    if (_savingGoal) throw StateError('A daily goal update is already pending');
    _goalRevision++;
    state = state.copyWith(dailyGoal: value, dailyGoalConfirmed: false);
  }

  Future<void> setJlptLevel(String value) =>
      replace(state.copyWith(jlptLevel: value));
  Future<void> setCallSettings(CallSettings value) =>
      replace(state.copyWith(callSettings: value));
}

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, UserPreferences>(
  UserPreferencesNotifier.new,
);
