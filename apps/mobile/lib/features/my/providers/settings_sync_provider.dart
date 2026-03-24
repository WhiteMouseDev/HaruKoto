import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> updateDailyGoal(int value) {
    return _runOptimistic(
      next: _preferences.copyWith(dailyGoal: value),
      remoteUpdate: () async {
        await _ref.read(myRepositoryProvider).updateProfile({
          'dailyGoal': value,
        });
      },
    );
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
    final previous = _preferences;
    await _ref.read(userPreferencesProvider.notifier).replace(next);

    try {
      await remoteUpdate();
      _invalidateDependents();
    } catch (_) {
      await _ref.read(userPreferencesProvider.notifier).replace(previous);
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
