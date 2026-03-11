import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/my/presentation/my_page.dart';
import '../../features/stats/presentation/stats_page.dart';
import '../../features/study/presentation/study_page.dart';
import '../../legacy/webview_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.uri.path;

      // Allow splash and legacy without auth check
      if (path == '/splash' || path == '/legacy') return null;

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
        path: '/legacy',
        builder: (context, state) => const WebViewScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                builder: (context, state) => const StudyPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const MyPage(),
              ),
            ],
          ),
        ],
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
    Future.delayed(const Duration(seconds: 2), () {
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
