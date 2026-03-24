import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_sheet_handle.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/profile_detail_model.dart';
import '../providers/my_provider.dart';
import 'widgets/profile_hero.dart';
// Hidden for free launch
// import 'widgets/subscription_section.dart';
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

    // Keep previous data during refresh to avoid full tree swap
    final data = profileAsync.hasValue ? profileAsync.value : null;
    final isInitialLoading = profileAsync.isLoading && data == null;
    final hasError = profileAsync.hasError && data == null;

    return Scaffold(
      appBar: AppBar(title: const Text('MY')),
      body: isInitialLoading
          ? _buildSkeleton(context)
          : hasError
              ? _buildError(context)
              : data == null
                  ? _buildSkeleton(context)
                  : _buildContent(context, theme, data),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, ProfileDetailModel data) {
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
            onEditNickname: () =>
                _showNicknameSheet(context, data.profile.nickname),
          ),
          const SizedBox(height: AppSizes.md),

          // Subscription — hidden for free launch (re-enable when IAP ready)
          // SubscriptionSection(
          //   onNavigateToPricing: () => context.push('/pricing'),
          //   onNavigateToManage: () => context.push('/my/subscription'),
          //   onNavigateToPayments: () => context.push('/my/payments'),
          // ),

          // Learning Stats
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(LucideIcons.barChart3,
                  size: 20, color: theme.colorScheme.primary),
              title: const Text('학습 통계', style: TextStyle(fontSize: 14)),
              trailing: Icon(LucideIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              onTap: () => context.push('/stats'),
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Settings
          const SettingsMenu(),
          const SizedBox(height: AppSizes.md),

          // App Settings
          const AppSettingsSection(),
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
            padding: const EdgeInsets.only(bottom: 120),
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
                  '연락처: 010-8595-9869',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  '이메일: whitemousedev@whitemouse.dev',
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
            icon: const Icon(LucideIcons.rotateCw, size: 18),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNicknameSheet(
      BuildContext context, String currentNickname) async {
    final nickname = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: AppSizes.sheetShape,
      builder: (_) => _NicknameSheet(currentNickname: currentNickname),
    );

    if (nickname == null || nickname.isEmpty || !mounted) return;
    await ref.read(myRepositoryProvider).updateProfile({'nickname': nickname});
    if (mounted) ref.invalidate(profileDetailProvider);
  }

  Future<void> _handleLogout() async {
    setState(() => _loggingOut = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    } catch (e) {
      debugPrint('[MyPage] Logout failed: $e');
      if (mounted) {
        setState(() => _loggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃에 실패했습니다')),
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    try {
      await ref.read(myRepositoryProvider).deleteAccount();
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    } catch (e) {
      debugPrint('[MyPage] Delete account failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정 삭제에 실패했습니다')),
        );
      }
    }
  }
}

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet({required this.currentNickname});

  final String currentNickname;

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 20),
            Text(
              '닉네임 변경',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '새로운 닉네임을 입력해주세요.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLength: 20,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '닉네임을 입력해주세요',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final nickname = _controller.text.trim();
                  if (nickname.isEmpty) return;
                  Navigator.of(context).pop(nickname);
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
      ),
    );
  }
}
