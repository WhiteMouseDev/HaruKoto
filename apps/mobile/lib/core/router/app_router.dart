import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/chat/presentation/contacts_page.dart';
import '../../features/chat/presentation/conversation_page.dart';
import '../../features/chat/presentation/conversation_feedback_page.dart';
import '../../features/chat/presentation/call_analyzing_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/kana/presentation/kana_hub_page.dart';
import '../../features/kana/presentation/kana_type_page.dart';
import '../../features/kana/presentation/kana_stage_page.dart';
import '../../features/kana/presentation/kana_quiz_page.dart';
import '../../features/kana/presentation/kana_chart_page.dart';
import '../../features/my/presentation/my_page.dart';
import '../../features/my/presentation/payments_page.dart';
import '../../features/stats/presentation/stats_page.dart';
import '../../features/practice/presentation/practice_page.dart';
import '../../features/study/presentation/study_page.dart';
import '../../features/study/presentation/learned_words_page.dart';
import '../../features/study/presentation/wrong_answers_page.dart';
import '../../features/study/presentation/wordbook_page.dart';
import '../../features/subscription/presentation/pricing_page.dart';
import '../../features/subscription/presentation/checkout_page.dart';
import '../../features/subscription/presentation/subscription_success_page.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.uri.path;

      // Allow splash, legacy, and onboarding without auth check
      if (path == '/splash' || path == '/legacy') return null;

      // Onboarding requires auth
      if (path == '/onboarding') {
        if (!isAuthenticated) return '/login';
        return null;
      }

      if (!isAuthenticated && path != '/login') return '/login';
      if (isAuthenticated && path == '/login') return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashRedirect(),
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
                builder: (context, state) => const PracticePage(),
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
                    path: 'call/analyzing',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const CallAnalyzingPage(
                        transcript: [],
                        durationSeconds: 0,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':conversationId',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['conversationId']!;
                      return _slideTransitionPage(
                        state: state,
                        child: ConversationPage(conversationId: id),
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
                routes: [
                  GoRoute(
                    path: 'payments',
                    pageBuilder: (context, state) => _slideTransitionPage(
                      state: state,
                      child: const PaymentsPage(),
                    ),
                  ),
                ],
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
      GoRoute(
        path: '/pricing',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const PricingPage(),
        ),
      ),
      GoRoute(
        path: '/subscription/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final planId = state.uri.queryParameters['planId'] ?? '';
          return _slideTransitionPage(
            state: state,
            child: CheckoutPage(planId: planId),
          );
        },
      ),
      GoRoute(
        path: '/subscription/success',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const SubscriptionSuccessPage(),
        ),
      ),
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
});

/// Splash with 2-second delay then redirect based on auth state
class _SplashRedirect extends ConsumerStatefulWidget {
  const _SplashRedirect();

  @override
  ConsumerState<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends ConsumerState<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      final isAuth = ref.read(isAuthenticatedProvider);
      if (isAuth) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}
