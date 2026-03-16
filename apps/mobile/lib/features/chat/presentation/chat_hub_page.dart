import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/call_settings_sheet.dart';
import '../../my/data/models/profile_detail_model.dart';
import '../../my/providers/my_provider.dart';
import '../providers/chat_provider.dart';
import '../data/models/scenario_model.dart';
import 'widgets/chat_loading_overlay.dart';
import 'widgets/scenario_list_view.dart';
import 'widgets/voice_tab.dart';
import 'widgets/text_tab.dart';

class ChatHubPage extends ConsumerStatefulWidget {
  const ChatHubPage({super.key});

  @override
  ConsumerState<ChatHubPage> createState() => _ChatHubPageState();
}

class _ChatHubPageState extends ConsumerState<ChatHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedCategory;
  String _categorySource = 'text';
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleStartConversation(ScenarioModel scenario) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.startConversation(scenario.id);
      if (!mounted) return;
      context.go('/chat/${result.conversationId}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '대화를 시작할 수 없습니다.';
        _starting = false;
      });
    }
  }

  Future<void> _handleFreeChat() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final scenarios = await repo.fetchScenarios(category: 'FREE');
      if (scenarios.isNotEmpty) {
        await _handleStartConversation(scenarios.first);
      } else {
        setState(() {
          _error = '자유 대화 시나리오가 없습니다.';
          _starting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '대화를 시작할 수 없습니다.';
        _starting = false;
      });
    }
  }

  void _showCallSettings(BuildContext context) {
    final profileAsync = ref.read(profileDetailProvider);
    final callSettings = profileAsync.hasValue
        ? profileAsync.value!.profile.callSettings
        : const CallSettings();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CallSettingsSheet(
          settings: callSettings,
          onChanged: (updated) async {
            await ref
                .read(myRepositoryProvider)
                .updateProfile({'callSettings': updated.toJson()});
            ref.invalidate(profileDetailProvider);
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_selectedCategory != null) {
      return ScenarioListView(
        category: _selectedCategory!,
        categorySource: _categorySource,
        starting: _starting,
        onBack: () => setState(() => _selectedCategory = null),
        onStartConversation: _handleStartConversation,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
                    child: Row(
                      children: [
                        Text(
                          'AI 회화',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.flaskConical,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                'Beta',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            LucideIcons.settings,
                            size: 20,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          tooltip: '통화 설정',
                          onPressed: () => _showCallSettings(context),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSizes.md),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.overlay(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: colorScheme.onSurface,
                        unselectedLabelColor:
                            colorScheme.onSurface.withValues(alpha: 0.5),
                        labelStyle: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.phone, size: 16),
                                SizedBox(width: 6),
                                Text('음성통화'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.messageCircle, size: 16),
                                SizedBox(width: 6),
                                Text('텍스트 회화'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      VoiceTab(
                        onSelectCategory: (cat) {
                          setState(() {
                            _categorySource = 'voice';
                            _selectedCategory = cat;
                          });
                        },
                      ),
                      TextTab(
                        onFreeChat: _handleFreeChat,
                        onSelectCategory: (cat) {
                          setState(() {
                            _categorySource = 'text';
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_starting) const ChatLoadingOverlay(),
            if (_error != null)
              Positioned(
                bottom: AppSizes.md,
                left: AppSizes.md,
                right: AppSizes.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.hkRedLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.hkRedLight),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
