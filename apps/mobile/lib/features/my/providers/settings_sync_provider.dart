import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/settings/call_settings.dart';
import '../../../core/settings/user_preferences.dart';
import '../../home/providers/home_provider.dart';
import '../../study/providers/study_provider.dart';
import 'my_provider.dart';

final settingsSyncServiceProvider = Provider<SettingsSyncService>((ref) {
  return SettingsSyncService(ref);
});

class SettingsSyncService {
  const SettingsSyncService(this._ref);

  final Ref _ref;

  UserPreferences get _preferences => _ref.read(userPreferencesProvider);

  Future<void> updateShowFurigana(bool value) {
    return _runOptimistic(
      next: _preferences.copyWith(showFurigana: value),
      remoteUpdate: () async {
        await _ref.read(myRepositoryProvider).updateProfile({
          'appSettings': {'showFurigana': value},
        });
      },
    );
  }

  Future<void> updateShowKana(bool value) {
    return _runOptimistic(
      next: _preferences.copyWith(showKana: value),
      remoteUpdate: () async {
        await _ref.read(myRepositoryProvider).updateProfile({
          'showKana': value,
        });
      },
    );
  }

  Future<void> updateDailyGoal(int value) async {
    final notifier = _ref.read(userPreferencesProvider.notifier);
    final previous = _preferences;
    final scope = await notifier.beginDailyGoalUpdate(value);
    try {
      if (!notifier.isCurrent(scope)) {
        throw const ApiException(message: '계정이 변경되어 목표를 다시 확인해주세요.');
      }
      await _ref.read(myRepositoryProvider).updateProfile({'dailyGoal': value});
      if (!_ref.mounted || !notifier.isCurrent(scope)) return;
      await notifier.finishDailyGoalUpdate(scope, value: value);
      if (!_ref.mounted ||
          _ref.read(currentAccountReaderProvider)() != scope.owner) {
        return;
      }
      _invalidateDependents();
      _ref.read(vocabularyPreviewRefreshProvider.notifier).refresh();
    } catch (_) {
      if (_ref.mounted) notifier.cancelDailyGoalUpdate(scope, previous);
      rethrow;
    }
  }

  Future<void> updateJlptLevel(String value) {
    return _runOptimistic(
      next: _preferences.copyWith(jlptLevel: value),
      remoteUpdate: () async {
        await _ref.read(myRepositoryProvider).updateProfile({
          'jlptLevel': value,
        });
      },
    );
  }

  Future<void> updateCallSettings(CallSettings value) {
    return _runOptimistic(
      next: _preferences.copyWith(callSettings: value),
      remoteUpdate: () async {
        await _ref.read(myRepositoryProvider).updateProfile({
          'callSettings': value.toJson(),
        });
      },
    );
  }

  Future<void> _runOptimistic({
    required UserPreferences next,
    required Future<void> Function() remoteUpdate,
  }) async {
    final notifier = _ref.read(userPreferencesProvider.notifier);
    final scope = notifier.requestScope;
    final previous = _preferences;
    await notifier.replace(next);
    try {
      if (!notifier.isCurrentAccount(scope)) {
        throw const ApiException(message: '계정이 변경되어 설정을 다시 확인해주세요.');
      }
      await remoteUpdate();
      if (_ref.mounted && notifier.isCurrentAccount(scope)) {
        _invalidateDependents();
      }
    } catch (_) {
      if (_ref.mounted && notifier.isCurrentAccount(scope)) {
        await notifier.replace(previous);
      }
      rethrow;
    }
  }

  void _invalidateDependents() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(profileDetailProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(chaptersProvider);
    _ref.invalidate(reviewSummaryProvider);
  }
}
