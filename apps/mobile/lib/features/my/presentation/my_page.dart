import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/sizes.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/my_provider.dart';
import 'widgets/profile_hero.dart';
import 'widgets/achievements_section.dart';
import 'widgets/subscription_section.dart';
import 'widgets/settings_menu.dart';
import 'widgets/app_settings_section.dart';
import 'widgets/info_section.dart';
import 'widgets/account_section.dart';

class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileDetailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MY')),
      body: profileAsync.when(
        loading: () => _buildSkeleton(context),
        error: (error, _) => _buildError(context),
        data: (data) {
          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: () async {
              ref.invalidate(profileDetailProvider);
              ref.invalidate(subscriptionStatusProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                // Profile Hero
                ProfileHero(
                  profile: data.profile,
                  summary: data.summary,
                  onEditNickname: () => _showNicknameSheet(context, data.profile.nickname),
                ),
                const SizedBox(height: AppSizes.md),

                // Achievements
                AchievementsSection(achievements: data.achievements),
                const SizedBox(height: AppSizes.md),

                // Subscription
                SubscriptionSection(
                  onNavigateToPricing: () => context.push('/pricing'),
                  onNavigateToPayments: () => context.push('/my/payments'),
                ),
                const SizedBox(height: AppSizes.md),

                // Settings
                SettingsMenu(
                  jlptLevel: data.profile.jlptLevel,
                  dailyGoal: data.profile.dailyGoal,
                  showKana: data.profile.showKana,
                  onUpdate: (field, value) async {
                    await ref
                        .read(myRepositoryProvider)
                        .updateProfile({field: value});
                    ref.invalidate(profileDetailProvider);
                  },
                ),
                const SizedBox(height: AppSizes.md),

                // App Settings
                AppSettingsSection(
                  notificationEnabled: data.profile.notificationEnabled,
                  callSettings: data.profile.callSettings,
                  onUpdate: (field, value) async {
                    await ref
                        .read(myRepositoryProvider)
                        .updateProfile({field: value});
                    ref.invalidate(profileDetailProvider);
                  },
                  onCallSettingsChanged: (settings) async {
                    await ref
                        .read(myRepositoryProvider)
                        .updateProfile({'callSettings': settings.toJson()});
                    ref.invalidate(profileDetailProvider);
                  },
                ),
                const SizedBox(height: AppSizes.md),

                // Info
                const InfoSection(),
                const SizedBox(height: AppSizes.md),

                // Account
                AccountSection(
                  onLogout: _handleLogout,
                  loggingOut: _loggingOut,
                  onDeleteAccount: _handleDeleteAccount,
                ),
                const SizedBox(height: AppSizes.md),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      Text(
                        '화이트마우스데브 (WhiteMouseDev)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '대표: 김건우',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        '사업자등록번호: 634-26-01985',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        '통신판매업신고번호: 2026-서울송파-0749',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        '주소: 서울특별시 송파구 양재대로 1218',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        'whitemousedev@whitemouse.dev',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        // Profile skeleton
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.cloudOff,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text('데이터를 불러올 수 없습니다', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(profileDetailProvider);
            },
            icon: Icon(LucideIcons.rotateCw, size: 18),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _showNicknameSheet(BuildContext context, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '닉네임 변경',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '새로운 닉네임을 입력해주세요.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: 20,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '닉네임을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final nickname = controller.text.trim();
                    if (nickname.isEmpty) return;
                    Navigator.pop(context);
                    await ref
                        .read(myRepositoryProvider)
                        .updateProfile({'nickname': nickname});
                    ref.invalidate(profileDetailProvider);
                    controller.dispose();
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _loggingOut = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    } catch (_) {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    try {
      await ref.read(myRepositoryProvider).deleteAccount();
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    } catch (_) {
      // Error handled silently
    }
  }
}
