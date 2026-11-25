import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widgetbook/widgetbook.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/haru_typography.dart';
import 'features/home/presentation/widgets/home_header.dart';
import 'features/study/presentation/widgets/quiz_progress_bar.dart';
import 'shared/widgets/app_card.dart';
import 'shared/widgets/app_error_retry.dart';
import 'shared/widgets/app_segmented_tabs.dart';
import 'shared/widgets/app_skeleton.dart';
import 'shared/widgets/bottom_nav.dart';
import 'shared/widgets/haru_button_styles.dart';

void main() {
  runApp(const ProviderScope(child: HarukotoWidgetbook()));
}

class HarukotoWidgetbook extends StatelessWidget {
  const HarukotoWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: AppTheme.light),
            WidgetbookTheme(name: 'Dark', data: AppTheme.dark),
          ],
        ),
      ],
      directories: [
        WidgetbookFolder(
          name: 'Shared',
          children: [
            WidgetbookComponent(
              name: 'Primary Button',
              useCases: [
                WidgetbookUseCase(
                  name: 'StyleGuide · 42 / 48',
                  builder: (context) => Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text('42pt · 퀴즈와 복습'),
                        FilledButton(
                          style: HaruButtonStyles.primary(context),
                          onPressed: () {},
                          child: const Text('퀴즈 풀기'),
                        ),
                        FilledButton(
                          style: HaruButtonStyles.primary(context),
                          onPressed: null,
                          child: const Text('퀴즈 풀기'),
                        ),
                        const SizedBox(height: 24),
                        const Text('48pt · 홈 학습 시작'),
                        FilledButton(
                          style: HaruButtonStyles.primary(
                            context,
                            size: HaruButtonSize.regular,
                          ),
                          onPressed: () {},
                          child: const Text('학습 시작'),
                        ),
                        FilledButton(
                          style: HaruButtonStyles.primary(
                            context,
                            size: HaruButtonSize.regular,
                          ),
                          onPressed: null,
                          child: const Text('학습 시작'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Quiz Category Tabs',
              useCases: [
                WidgetbookUseCase(
                  name: 'Selected and Unselected',
                  builder: (context) {
                    var selected = 0;
                    const labels = ['단어', '문법'];
                    return Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.all(20),
                        child: StatefulBuilder(
                          builder: (context, setState) => Row(
                            spacing: 4,
                            children: [
                              for (var i = 0; i < labels.length; i++)
                                TextButton(
                                  style: HaruButtonStyles.pillTab(
                                    context,
                                    selected: selected == i,
                                    minimumWidth: 63,
                                  ),
                                  onPressed: () => setState(() => selected = i),
                                  child: Semantics(
                                    selected: selected == i,
                                    inMutuallyExclusiveGroup: true,
                                    child: Text(labels[i]),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Typography',
              useCases: [
                WidgetbookUseCase(
                  name: 'Korean and Japanese',
                  builder: (_) => Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        Text('학습', style: HaruTypography.krTitle2),
                        Text('오늘 복습할 표현', style: HaruTypography.krTitle3),
                        Text('학습한 내용을 복습해요.', style: HaruTypography.krBody3),
                        Text('春のように咲く私の日本語', style: HaruTypography.jpBody3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppCard',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => const Scaffold(
                    body: Padding(
                      padding: EdgeInsets.all(20),
                      child: AppCard(
                        child: Text('오늘의 학습 · 20문제'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppSegmentedTabs',
              useCases: [
                WidgetbookUseCase(
                  name: 'Study Statistics',
                  builder: (_) {
                    var selectedIndex = 0;
                    return Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.all(20),
                        child: StatefulBuilder(
                          builder: (_, setState) => AppSegmentedTabs(
                            labels: const ['기간별', '학습별', 'JLPT 진도'],
                            compact: true,
                            selectedIndex: selectedIndex,
                            onChanged: (index) {
                              setState(() => selectedIndex = index);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppErrorRetry',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Scaffold(
                    body: AppErrorRetry(
                      message: context.knobs.string(
                        label: 'Message',
                        initialValue: '데이터를 불러올 수 없습니다',
                      ),
                      submessage: context.knobs.string(
                        label: 'Submessage',
                        initialValue: '네트워크 연결을 확인해주세요',
                      ),
                      onRetry: () {},
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppSkeleton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Scaffold(
                    body: AppSkeleton(
                      itemCount: context.knobs.int.slider(
                        label: 'Item Count',
                        initialValue: 5,
                        min: 1,
                        max: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'BottomNav',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) {
                    final index = context.knobs.int.slider(
                      label: 'Current Index',
                      initialValue: 0,
                      min: 0,
                      max: 4,
                    );

                    return Scaffold(
                      body: const Center(child: Text('Body Preview')),
                      bottomNavigationBar: BottomNav(
                        currentIndex: index,
                        onTap: (_) {},
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Home',
          children: [
            WidgetbookComponent(
              name: 'HomeHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Scaffold(
                    body: SafeArea(
                      child: HomeHeader(
                        nickname: context.knobs.string(
                          label: 'Nickname',
                          initialValue: '학습자',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Study',
          children: [
            WidgetbookComponent(
              name: 'QuizProgressBar',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) {
                    final progress = context.knobs.double.slider(
                      label: 'Progress',
                      initialValue: 0.4,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      precision: 2,
                    );
                    final streak = context.knobs.int.slider(
                      label: 'Streak',
                      initialValue: 3,
                      min: 0,
                      max: 10,
                    );
                    final showStreak = context.knobs.boolean(
                      label: 'Show Streak',
                      initialValue: true,
                    );

                    return Scaffold(
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: QuizProgressBar(
                            progress: progress,
                            streak: streak,
                            showStreak: showStreak,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
