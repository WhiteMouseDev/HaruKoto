import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/providers/home_provider.dart';

/// Resolves post-auth destination: /onboarding or /home.
/// Used by both login handlers and splash redirect to avoid duplication.
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
  } catch (_) {
    if (context.mounted) context.go('/home');
  }
}
