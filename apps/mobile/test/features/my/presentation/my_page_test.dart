import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/presentation/my_page.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/account_section.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MyPage', () {
    testWidgets('shows loaded profile content', (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeMyRepository();
      try {
        await tester.pumpWidget(await _buildMyPage(repository));
        await tester.pumpAndSettle();

        expect(find.text('마이페이지'), findsOneWidget);
        expect(find.text('하루님'), findsOneWidget);
        expect(find.text('N5'), findsWidgets);
        expect(find.text('LV.2'), findsOneWidget);
        expect(find.text('320/1000 XP'), findsOneWidget);
        expect(find.bySemanticsLabel('총 학습일 5일'), findsOneWidget);
        expect(find.bySemanticsLabel('학습 단어 42개'), findsOneWidget);
        expect(find.bySemanticsLabel('총 XP 320'), findsOneWidget);
        expect(find.bySemanticsLabel('최장 연속 7일'), findsOneWidget);
        expect(find.text('나의 학습 통계'), findsOneWidget);
        expect(find.text('앱 설정'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('shows retry state when profile load fails', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final profileCompleter = Completer<ProfileDetailModel>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAccountIdProvider.overrideWithValue('user-1'),
            currentAccountReaderProvider.overrideWithValue(() => 'user-1'),
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
      await tester.tap(find.byTooltip('닉네임 변경'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  새하루  ');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(repository.updatedProfiles, [
        {'nickname': '새하루'},
      ]);
    });

    testWidgets('nickname editor does not apply after switching accounts',
        (tester) async {
      final repository = _FakeMyRepository();
      var activeAccount = 'user-1';
      await tester.pumpWidget(
        await _buildMyPage(repository, accountReader: () => activeAccount),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닉네임 변경'));
      await tester.pumpAndSettle();

      activeAccount = 'user-2';
      await tester.enterText(find.byType(TextField), '새하루');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(repository.updatedProfiles, isEmpty);
    });

    testWidgets('learning statistics keeps the MY route', (tester) async {
      final router = GoRouter(
        initialLocation: '/my',
        routes: [
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPage(),
            routes: [
              GoRoute(
                path: 'stats',
                builder: (context, state) =>
                    const Scaffold(body: Text('통계 경로 도착')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(await _buildMyPage(
        _FakeMyRepository(),
        router: router,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나의 학습 통계'));
      await tester.pumpAndSettle();
      expect(find.text('통계 경로 도착'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('나의 학습 통계'), findsOneWidget);
    });

    testWidgets('opens learning and app settings from their rows',
        (tester) async {
      final repository = _FakeMyRepository();
      await tester.pumpWidget(await _buildMyPage(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('JLPT 레벨'));
      await tester.pumpAndSettle();
      expect(find.text('JLPT 레벨 선택'), findsOneWidget);
      expect(find.text('N1'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('테마 선택').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('다크'), findsOneWidget);
      expect(repository.updatedProfiles, isEmpty);
    });

    testWidgets('supports long nicknames and settings in a 320dp large font',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const nickname = '하루코토에서일본어를열심히배우는학습자';
      await tester.pumpWidget(await _buildMyPage(
        _FakeMyRepository(ProfileDetailModel.fromJson({
          'profile': {
            'id': 'user-1',
            'nickname': nickname,
            'jlptLevel': 'ABSOLUTE_ZERO',
            'showKana': true,
          },
        })),
        brightness: Brightness.dark,
        textScale: 2,
      ));
      await tester.pumpAndSettle();
      expect(find.text('$nickname님'), findsOneWidget);
      expect(find.text('입문'), findsWidgets);
      await tester.scrollUntilVisible(find.text('회원탈퇴'), 220);
      expect(find.text('고객센터'), findsOneWidget);
      expect(find.text('회원탈퇴'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      await tester.tap(find.text('회원탈퇴'));
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

Future<Widget> _buildMyPage(
  _FakeMyRepository repository, {
  String? Function()? accountReader,
  GoRouter? router,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      currentAccountIdProvider.overrideWithValue('user-1'),
      currentAccountReaderProvider
          .overrideWithValue(accountReader ?? () => 'user-1'),
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      myRepositoryProvider.overrideWith((ref) => repository),
    ],
    child: router != null
        ? MaterialApp.router(routerConfig: router)
        : MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const MyPage(),
          ),
  );
}

class _FakeMyRepository extends MyRepository {
  _FakeMyRepository([this.detail = _profileDetail]) : super(Dio());

  final ProfileDetailModel detail;
  final updatedProfiles = <Map<String, dynamic>>[];

  @override
  Future<ProfileDetailModel> fetchProfileDetail() async {
    return detail;
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
