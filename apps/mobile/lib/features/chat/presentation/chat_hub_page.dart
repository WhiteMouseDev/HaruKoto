import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/settings/call_settings.dart';
import '../../../core/theme/haru_typography.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/call_settings_sheet.dart';
import '../../my/providers/settings_sync_provider.dart';
import '../data/models/conversation_journey_episode.dart';
import '../data/models/scenario_model.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_mode_provider.dart';
import '../providers/conversation_journey_progress_provider.dart';
import 'chat_entry_mode.dart';
import 'conversation_launch.dart';
import 'voice_call_launch.dart';
import 'widgets/chat_loading_overlay.dart';
import 'widgets/conversation_journey_card.dart';
import 'widgets/conversation_journey_sheet.dart';
import 'widgets/scenario_list_view.dart';
import 'widgets/scenario_preparation_sheet.dart';
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
  ChatEntryMode _entryMode = ChatEntryMode.text;
  bool _starting = false;
  bool _openingJourney = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: ref.read(chatModeProvider),
    );
    _tabController.addListener(_rememberMode);
  }

  void _rememberMode() {
    if (!_tabController.indexIsChanging) {
      unawaited(
          ref.read(chatModeProvider.notifier).select(_tabController.index));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_rememberMode);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleStartConversation(
    ScenarioModel scenario, {
    String? expectedAccountId,
  }) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.startConversation(scenario.id);
      if (!mounted) return;
      setState(() => _starting = false);
      if (expectedAccountId != null &&
          ref.read(currentAccountReaderProvider)() != expectedAccountId) {
        return;
      }
      openConversationPage(
        context,
        conversationId: result.conversationId,
        initialScenario: scenario,
        firstMessage: result.firstMessage,
      );
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
      if (!mounted) return;
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

  Future<void> _openJourney(
    String accountId,
    Map<String, ScenarioModel> available,
    Set<String> practicedIds,
    ConversationJourneyEpisode recommended, {
    bool showAll = false,
  }) async {
    if (_openingJourney || _starting) return;
    _openingJourney = true;
    try {
      final episode = showAll
          ? await showModalBottomSheet<ConversationJourneyEpisode>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => ConversationJourneySheet(
                episodes: tokyoFirstDayEpisodes,
                scenarios: available,
                practicedIds: practicedIds,
                recommendedId: recommended.scenarioId,
              ),
            )
          : recommended;
      if (!mounted ||
          episode == null ||
          ref.read(currentAccountReaderProvider)() != accountId) {
        return;
      }
      final scenario = available[episode.scenarioId];
      if (scenario == null) return;
      final mode = await showModalBottomSheet<ChatEntryMode>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => ScenarioPreparationSheet(
          scenario: scenario,
          journeyEpisode: episode,
        ),
      );
      if (!mounted ||
          mode == null ||
          ref.read(currentAccountReaderProvider)() != accountId) {
        return;
      }
      if (mode == ChatEntryMode.voice) {
        openVoiceCallPage(context, scenarioId: scenario.id, scenario: scenario);
      } else {
        await _handleStartConversation(scenario, expectedAccountId: accountId);
      }
    } finally {
      _openingJourney = false;
    }
  }

  Widget _buildJourneyCard(BuildContext context, WidgetRef ref, Widget? child) {
    final accountId = ref.watch(currentAccountIdProvider);
    if (accountId == null) return const SizedBox.shrink();
    final catalog = ref.watch(scenariosProvider('TRAVEL'));
    if (catalog.isLoading || catalog.hasError || !catalog.hasValue) {
      return const SizedBox.shrink();
    }
    final available = {
      for (final scenario in catalog.requireValue) scenario.id: scenario,
    };
    if (!tokyoFirstDayEpisodes
        .every((episode) => available.containsKey(episode.scenarioId))) {
      return const SizedBox.shrink();
    }
    final progress = ref.watch(conversationJourneyProgressProvider(accountId));
    if (progress.isLoading || progress.hasError || !progress.hasValue) {
      return const SizedBox.shrink();
    }
    final practicedIds = progress.requireValue;
    final recommended = tokyoFirstDayEpisodes.firstWhere(
      (episode) => !practicedIds.contains(episode.scenarioId),
      orElse: () => tokyoFirstDayEpisodes.first,
    );
    return ConversationJourneyCard(
      episode: recommended,
      scenario: available[recommended.scenarioId]!,
      practicedCount: practicedIds.length,
      totalCount: tokyoFirstDayEpisodes.length,
      isRecommendedPracticed: practicedIds.contains(recommended.scenarioId),
      onPrepare: () =>
          _openJourney(accountId, available, practicedIds, recommended),
      onViewAll: () => _openJourney(
        accountId,
        available,
        practicedIds,
        recommended,
        showAll: true,
      ),
    );
  }

  Future<void> _showCallSettings(BuildContext context) async {
    final callSettings = ref.read(userPreferencesProvider).callSettings;

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showModalBottomSheet<CallSettings>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CallSettingsSheet(settings: callSettings),
    );

    if (updated == null || !context.mounted) return;
    try {
      await ref.read(settingsSyncServiceProvider).updateCallSettings(updated);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('통화 설정이 저장되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('설정 저장에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    if (_selectedCategory != null) {
      return ScenarioListView(
        category: _selectedCategory!,
        entryMode: _entryMode,
        starting: _starting,
        errorMessage: _error,
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
                      AppSizes.pageHorizontal,
                      10,
                      AppSizes.pageHorizontal - AppSizes.gap,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              '실전회화',
                              style: HaruTypography.krTitle2.copyWith(
                                color: isLight
                                    ? AppColors.redesignForeground
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            LucideIcons.settings,
                            size: AppSizes.iconMd,
                            color: colorScheme.onSurfaceVariant,
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
                    padding: AppSizes.pageHorizontalEdge,
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) => AppSegmentedTabs(
                        compact: true,
                        labelFontWeight: FontWeight.w500,
                        labels: const ['회화 연습', 'AI 친구 통화'],
                        selectedIndex: _tabController.index,
                        onChanged: _tabController.animateTo,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      TextTab(
                        journeyCard: Consumer(builder: _buildJourneyCard),
                        onFreeChat: _handleFreeChat,
                        onSelectCategory: (cat) {
                          setState(() {
                            _entryMode = ChatEntryMode.voice;
                            _selectedCategory = cat;
                          });
                        },
                      ),
                      const VoiceTab(),
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
