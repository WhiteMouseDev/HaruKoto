import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/theme/text_theme.dart';
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

  bool _isCurrent(String? owner) =>
      mounted &&
      owner != null &&
      ref.read(currentAccountIdProvider) == owner &&
      ref.read(currentAccountReaderProvider)() == owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = ref.watch(currentAccountIdProvider);
    ref.watch(currentAccountReaderProvider);
    final profileAsync = ref.watch(profileDetailProvider);

    final candidate = profileAsync.value;
    final data = _isCurrent(owner) &&
            candidate != null &&
            (candidate.profile.id == owner ||
                candidate.profile.id.isEmpty &&
                    !profileAsync.isLoading &&
                    !profileAsync.hasError)
        ? candidate
        : null;
    final hasError = profileAsync.hasError && data == null;
    final light = theme.brightness == Brightness.light;

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: redesignFontFamily),
        switchTheme: light
            ? theme.switchTheme.copyWith(
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.redesignVocabulary
                        : null),
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white
                        : null),
              )
            : theme.switchTheme,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    '마이페이지',
                    style: TextStyle(
                      fontFamily: redesignFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: -0.5,
                      color: light
                          ? AppColors.redesignForeground
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: hasError
                    ? _buildError(context)
                    : data == null || owner == null
                        ? _buildSkeleton(context)
                        : _buildContent(context, theme, data, owner),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme,
      ProfileDetailModel data, String owner) {
    final light = theme.brightness == Brightness.light;
    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: () async {
        ref.invalidate(profileDetailProvider);
        ref.invalidate(subscriptionStatusProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
        children: [
          // Profile Hero
          ProfileHero(
            profile: data.profile,
            summary: data.summary,
            onEditNickname: () =>
                _showNicknameSheet(context, owner, data.profile.nickname),
          ),
          const SizedBox(height: 8),

          // Subscription — hidden for free launch (re-enable when IAP ready)
          // SubscriptionSection(
          //   onNavigateToPricing: () => context.push('/pricing'),
          //   onNavigateToManage: () => context.push('/my/subscription'),
          //   onNavigateToPayments: () => context.push('/my/payments'),
          // ),

          // Learning Stats
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: light
                ? const Color(0xFFFEF0F2)
                : theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              minTileHeight: 48,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Image.asset(
                'assets/icons/figma-my-stats.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              title: const Text('나의 학습 통계',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: Image.asset(
                'assets/icons/figma-home-arrow.png',
                width: 6.25,
                height: 11,
                color: light ? null : theme.colorScheme.onSurfaceVariant,
                excludeFromSemantics: true,
              ),
              onTap: () => context.push('/my/stats'),
            ),
          ),
          const SizedBox(height: 40),

          // Settings
          const SettingsMenu(),
          const SizedBox(height: 40),

          // App Settings
          const AppSettingsSection(),
          const SizedBox(height: 40),

          // Info
          const InfoSection(),
          const SizedBox(height: 40),

          // Account
          AccountSection(
            onLogout: () => _handleLogout(owner),
            loggingOut: _loggingOut,
            onDeleteAccount: () => _handleDeleteAccount(owner),
          ),
          const SizedBox(height: AppSizes.md),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: light
                  ? AppColors.redesignSurface
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
      BuildContext context, String owner, String currentNickname) async {
    if (!_isCurrent(owner)) return;
    final nickname = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: AppSizes.sheetShape,
      builder: (_) => _NicknameSheet(currentNickname: currentNickname),
    );

    if (nickname == null || nickname.isEmpty || !_isCurrent(owner)) return;
    try {
      await ref
          .read(myRepositoryProvider)
          .updateProfile({'nickname': nickname});
      if (_isCurrent(owner)) ref.invalidate(profileDetailProvider);
    } catch (_) {
      if (!_isCurrent(owner) || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 변경하지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _handleLogout(String owner) async {
    if (!_isCurrent(owner) || _loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    } catch (e) {
      debugPrint('[MyPage] Logout failed: $e');
      if (mounted && _isCurrent(owner)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _handleDeleteAccount(String owner) async {
    if (!_isCurrent(owner)) return;
    try {
      await ref.read(myRepositoryProvider).deleteAccount();
      if (!_isCurrent(owner)) return;
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    } catch (e) {
      debugPrint('[MyPage] Delete account failed: $e');
      if (mounted && _isCurrent(owner)) {
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
