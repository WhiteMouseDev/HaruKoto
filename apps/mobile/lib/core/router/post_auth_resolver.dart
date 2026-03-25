import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/providers/home_provider.dart';

/// Resolves post-auth destination based on profile state.
/// Handles errors by type instead of catch-all.
Future<void> resolvePostAuthDestination(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final profile = await ref.read(homeRepositoryProvider).fetchProfile();
    if (!context.mounted) return;
    if (!profile.onboardingCompleted) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  } on DioException catch (e) {
    if (!context.mounted) return;

    final statusCode = e.response?.statusCode;

    if (statusCode == 401 || statusCode == 403) {
      // 인증 만료/무효 → 세션 정리 후 로그인으로
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) return;
      context.go('/login');
    } else {
      // 네트워크/서버 에러 → 홈으로 (홈은 profileProvider를 watch해서 자체 에러 표시/재시도 가능)
      context.go('/home');
    }
  } catch (_) {
    // 예상치 못한 에러 → 홈으로 (자체 에러 핸들링에 위임)
    if (context.mounted) context.go('/home');
  }
}
