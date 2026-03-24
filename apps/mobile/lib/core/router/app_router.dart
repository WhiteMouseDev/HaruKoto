import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/chat/presentation/contacts_page.dart';
import '../../features/chat/presentation/conversation_page.dart';
import '../../features/chat/presentation/conversation_feedback_page.dart';
import '../../features/chat/presentation/conversation_launch.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/kana/presentation/kana_hub_page.dart';
import '../../features/kana/presentation/kana_type_page.dart';
import '../../features/kana/presentation/kana_stage_page.dart';
import '../../features/kana/presentation/kana_quiz_page.dart';
import '../../features/kana/presentation/kana_chart_page.dart';
import '../../features/my/presentation/my_page.dart';
// Hidden for free launch — re-enable when IAP ready
// import '../../features/my/presentation/payments_page.dart';
// import '../../features/my/presentation/subscription_manage_page.dart';
import '../../features/stats/presentation/stats_page.dart';
import '../../features/practice/presentation/practice_page.dart';
import '../../features/study/presentation/study_page.dart';
import '../../features/study/presentation/lesson_list_page.dart';
import '../../features/study/presentation/lesson_page.dart';
import '../../features/study/presentation/legacy_study_page.dart';
import '../../features/study/presentation/learned_words_page.dart';
import '../../features/study/presentation/wrong_answers_page.dart';
import '../../features/study/presentation/wordbook_page.dart';
// Hidden for free launch — re-enable when IAP ready
// import '../../features/subscription/presentation/pricing_page.dart';
// import '../../features/subscription/presentation/checkout_page.dart';
// import '../../features/subscription/presentation/subscription_success_page.dart';
import '../../features/legal/presentation/privacy_page.dart';
import '../../features/legal/presentation/terms_page.dart';
import '../../features/notifications/presentation/notification_page.dart';
import '../../legacy/webview_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _slideTransitionPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}

/// Notifier that triggers GoRouter redirect re-evaluation on auth changes.
/// GoRouter subscribes to this via refreshListenable — no router rebuild needed.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen<bool>(isAuthenticatedProvider, (_, __) => notifier.notify());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final path = state.uri.path;

      // Allow splash and legacy without auth check
      if (path == '/splash' || path == '/legacy') return null;

      // Onboarding requires auth
      if (path == '/onboarding') {
        if (!isAuthenticated) return '/login';
        return null;
      }

      if (!isAuthenticated && path != '/login') return '/login';
      if (isAuthenticated && path == '/login') return '/splash?postLogin=1';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => _SplashRedirect(
          skipDelay: state.uri.queryParameters['postLogin'] == '1',
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/legacy',
        builder: (context, state) => const WebViewScreen(),
      ),

      // === Main app shell with bottom nav ===
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),

          // Tab 1: Study
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                builder: (context, state) => const StudyPage(),
                routes: [
                  // Study sub-pages
                  GoRoute(
                    path: 'learned-words',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const LearnedWordsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'wrong-answers',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const WrongAnswersPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'wordbook',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const WordbookPage(),
                    ),
                  ),

                  // Lesson learning routes
                  GoRoute(
                    path: 'lessons',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const LessonListPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: ':lessonId',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final lessonId = state.pathParameters['lessonId']!;
                          return _slideTransitionPage(
                            state: state,
                            child: LessonPage(lessonId: lessonId),
                          );
                        },
                      ),
                    ],
                  ),

                  // Legacy study tab content routes
                  GoRoute(
                    path: 'legacy/:category',
                    pageBuilder: (context, state) {
                      final category = state.pathParameters['category']!;
                      return _slideTransitionPage(
                        state: state,
                        child: LegacyStudyPage(category: category),
                      );
                    },
                  ),

                  // Kana learning routes
                  GoRoute(
                    path: 'kana',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const KanaHubPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'chart',
                        pageBuilder: (context, state) => _slideTransitionPage(
                          state: state,
                          child: const KanaChartPage(),
                        ),
                      ),
                      GoRoute(
                        path: ':type',
                        pageBuilder: (context, state) {
                          final type = state.pathParameters['type']!;
                          return _slideTransitionPage(
                            state: state,
                            child: KanaTypePage(type: type),
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'stage/:number',
                            parentNavigatorKey: _rootNavigatorKey,
                            pageBuilder: (context, state) {
                              final type = state.pathParameters['type']!;
                              final number =
                                  int.parse(state.pathParameters['number']!);
                              return _slideTransitionPage(
                                state: state,
                                child: KanaStagePage(
                                    type: type, stageNumber: number),
                              );
                            },
                          ),
                          GoRoute(
                            path: 'quiz',
                            parentNavigatorKey: _rootNavigatorKey,
                            pageBuilder: (context, state) {
                              final type = state.pathParameters['type']!;
                              final mode =
                                  state.uri.queryParameters['mode'] ?? 'random';
                              final isMaster =
                                  state.uri.queryParameters['master'] == 'true';
                              return _slideTransitionPage(
                                state: state,
                                child: KanaQuizPage(
                                  type: type,
                                  mode: mode,
                                  isMaster: isMaster,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Tab 2: Practice
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practice',
                builder: (context, state) => PracticePage(
                  initialCategory: state.extra as String?,
                ),
              ),
            ],
          ),

          // Tab 3: Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatPage(),
                routes: [
                  GoRoute(
                    path: 'call/contacts',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const ContactsPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':conversationId',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['conversationId']!;
                      final launchData = state.extra is ConversationLaunchData
                          ? state.extra as ConversationLaunchData
                          : null;
                      return _slideTransitionPage(
                        state: state,
                        child: ConversationPage(
                          conversationId: id,
                          initialScenario: launchData?.initialScenario,
                          firstMessage: launchData?.firstMessage,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'feedback',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['conversationId']!;
                          return _slideTransitionPage(
                            state: state,
                            child: ConversationFeedbackPage(conversationId: id),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Tab 4: My
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const MyPage(),
                // Subscription routes — hidden for free launch
                routes: const [],
              ),
            ],
          ),
        ],
      ),

      // === Full-screen routes (outside shell) ===
      GoRoute(
        path: '/stats',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const StatsPage(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const NotificationPage(),
        ),
      ),
      // Pricing/Subscription routes — hidden for free launch (re-enable when IAP ready)
      // GoRoute(path: '/pricing', ...),
      // GoRoute(path: '/subscription/checkout', ...),
      // GoRoute(path: '/subscription/success', ...),
      GoRoute(
        path: '/legal/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const PrivacyPage(),
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const TermsPage(),
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Splash resolver: shows splash animation on cold start (1.5s),
/// or resolves immediately after login (skipDelay=true).
class _SplashRedirect extends ConsumerStatefulWidget {
  final bool skipDelay;
  const _SplashRedirect({this.skipDelay = false});

  @override
  ConsumerState<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends ConsumerState<_SplashRedirect> {
  bool _minTimeElapsed = false;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipDelay) {
      // Post-login: skip splash delay, resolve immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _minTimeElapsed = true;
        _tryRedirect();
      });
    } else {
      // Cold start: show splash for 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _minTimeElapsed = true;
        _tryRedirect();
      });
    }
  }

  void _tryRedirect() {
    if (_redirected || !_minTimeElapsed || !mounted) return;
    _redirected = true;
    _doRedirect();
  }

  Future<void> _doRedirect() async {
    // Use Supabase session directly — more reliable than stream provider
    // which may emit initial "no session" before restoration completes
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.isExpired) {
      if (mounted) context.go('/login');
      return;
    }

    // Check onboarding status
    try {
      final profile = await ref.read(homeRepositoryProvider).fetchProfile();
      if (!mounted) return;
      if (!profile.onboardingCompleted) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    } catch (_) {
      // If profile fetch fails, go home anyway (existing user)
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Post-login: show blank screen (same background) to avoid splash flash
    if (widget.skipDelay) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.authGradient,
          ),
        ),
      );
    }
    return const SplashPage();
  }
}
