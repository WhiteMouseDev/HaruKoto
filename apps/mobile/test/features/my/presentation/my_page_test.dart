import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/presentation/my_page.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/account_section.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MyPage', () {
    testWidgets('shows loaded profile content', (tester) async {
      final repository = _FakeMyRepository();
      await tester.pumpWidget(await _buildMyPage(repository));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('하루'), findsOneWidget);
      expect(find.text('N5'), findsWidgets);
      expect(find.text('학습 통계'), findsOneWidget);
      expect(find.text('앱 설정'), findsOneWidget);
    });

    testWidgets('shows retry state when profile load fails', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final profileCompleter = Completer<ProfileDetailModel>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            profileDetailProvider.overrideWith(
              (ref) => profileCompleter.future,
            ),
          ],
          child: const MaterialApp(home: MyPage()),
        ),
      );

      profileCompleter.completeError(Exception('profile down'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('데이터를 불러올 수 없습니다'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('trims nickname and patches profile', (tester) async {
      final repository = _FakeMyRepository();
      await tester.pumpWidget(await _buildMyPage(repository));

      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.pencil));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  새하루  ');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(repository.updatedProfiles, [
        {'nickname': '새하루'},
      ]);
    });
  });

  group('AccountSection', () {
    testWidgets('requires exact confirmation text before deleting account',
        (tester) async {
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSection(
              onLogout: () {},
              loggingOut: false,
              onDeleteAccount: () {
                deleted = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('회원 탈퇴'));
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(TextButton, '회원 탈퇴').last;
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '탈퇴');
      await tester.pump();
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });
}

Future<Widget> _buildMyPage(_FakeMyRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      myRepositoryProvider.overrideWith((ref) => repository),
    ],
    child: const MaterialApp(home: MyPage()),
  );
}

class _FakeMyRepository extends MyRepository {
  _FakeMyRepository() : super(Dio());

  final updatedProfiles = <Map<String, dynamic>>[];

  @override
  Future<ProfileDetailModel> fetchProfileDetail() async {
    return _profileDetail;
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
    updatedProfiles.add(Map<String, dynamic>.from(data));
  }
}

const _profileDetail = ProfileDetailModel(
  profile: ProfileInfo(
    id: 'user-1',
    nickname: '하루',
    jlptLevel: 'N5',
    dailyGoal: 10,
    experiencePoints: 320,
    level: 2,
    levelProgress: LevelProgress(currentXp: 320, xpForNext: 1000),
    streakCount: 3,
    longestStreak: 7,
    showKana: true,
    appSettings: {'showFurigana': true},
    createdAt: '2026-01-01T00:00:00Z',
  ),
  summary: ProfileSummary(
    totalWordsStudied: 42,
    totalQuizzesCompleted: 8,
    totalStudyDays: 5,
    totalXpEarned: 320,
  ),
  achievements: [],
);
