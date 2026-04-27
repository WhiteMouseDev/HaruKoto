import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/core/settings/user_preferences.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_context_reader.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';

void main() {
  group('VoiceCallStartContextReader', () {
    test('builds connection context from user preferences and profile',
        () async {
      const callSettings = CallSettings(
        silenceDurationMs: 900,
        subtitleEnabled: false,
      );
      final reader = VoiceCallStartContextReader(
        readPreferences: () => const UserPreferences(
          jlptLevel: 'N3',
          callSettings: callSettings,
        ),
        readProfile: () => AsyncValue.data(_profileDetail('Tester')),
        readProfileFuture: () async => _profileDetail('Ignored'),
      );

      final context = await reader.read();
      final input = context.toConnectionInput(
        const VoiceCallSessionRequest(
          characterId: 'char-1',
          characterName: '하루',
        ),
      );

      expect(context.callSettings, callSettings);
      expect(context.userNickname, 'Tester');
      expect(context.jlptLevel, 'N3');
      expect(input.callSettings, callSettings);
      expect(input.userNickname, 'Tester');
      expect(input.jlptLevel, 'N3');
      expect(input.request.characterId, 'char-1');
    });

    test('waits for profile future when profile is still loading', () async {
      final reader = VoiceCallStartContextReader(
        readPreferences: () => const UserPreferences(),
        readProfile: () => const AsyncValue<ProfileDetailModel>.loading(),
        readProfileFuture: () async => _profileDetail('LoadedTester'),
      );

      final context = await reader.read();

      expect(context.userNickname, 'LoadedTester');
    });

    test('falls back to default nickname when profile loading fails', () async {
      final reader = VoiceCallStartContextReader(
        readPreferences: () => const UserPreferences(),
        readProfile: () => const AsyncValue<ProfileDetailModel>.loading(),
        readProfileFuture: () => Future<ProfileDetailModel>.error(
          StateError('profile failed'),
        ),
      );

      final context = await reader.read();

      expect(context.userNickname, '학습자');
    });

    test('falls back to default nickname when profile nickname is empty',
        () async {
      final reader = VoiceCallStartContextReader(
        readPreferences: () => const UserPreferences(),
        readProfile: () => AsyncValue.data(_profileDetail('   ')),
        readProfileFuture: () async => _profileDetail('Ignored'),
      );

      final context = await reader.read();

      expect(context.userNickname, '학습자');
    });
  });
}

ProfileDetailModel _profileDetail(String nickname) {
  return ProfileDetailModel(
    profile: ProfileInfo(
      id: 'profile-1',
      nickname: nickname,
      jlptLevel: 'N5',
      dailyGoal: 10,
      experiencePoints: 0,
      level: 1,
      levelProgress: const LevelProgress(currentXp: 0, xpForNext: 100),
      streakCount: 0,
      longestStreak: 0,
      showKana: true,
      createdAt: '2026-03-24T00:00:00Z',
    ),
    summary: const ProfileSummary(
      totalWordsStudied: 0,
      totalQuizzesCompleted: 0,
      totalStudyDays: 0,
      totalXpEarned: 0,
    ),
    achievements: const [],
  );
}
