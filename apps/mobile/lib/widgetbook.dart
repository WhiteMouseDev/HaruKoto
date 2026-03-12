import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widgetbook/widgetbook.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/widgets/home_header.dart';
import 'features/study/presentation/widgets/quiz_progress_bar.dart';
import 'features/study/presentation/widgets/tab_switcher.dart';
import 'shared/widgets/app_card.dart';
import 'shared/widgets/app_error_retry.dart';
import 'shared/widgets/app_skeleton.dart';
import 'shared/widgets/bottom_nav.dart';

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
              name: 'AppCard',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) {
                    final text = context.knobs.string(
                      label: 'Text',
                      initialValue: '카드 콘텐츠 미리보기',
                    );
                    return Scaffold(
                      body: Center(
                        child: AppCard(
                          child: Text(
                            text,
                            style: Theme.of(context).textTheme.bodyLarge,
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
              name: 'TabSwitcher',
              useCases: [
                WidgetbookUseCase(
                  name: 'Interactive',
                  builder: (context) => const Scaffold(
                    body: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: _TabSwitcherPreview(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

class _TabSwitcherPreview extends StatefulWidget {
  const _TabSwitcherPreview();

  @override
  State<_TabSwitcherPreview> createState() => _TabSwitcherPreviewState();
}

class _TabSwitcherPreviewState extends State<_TabSwitcherPreview> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return TabSwitcher(
      activeTab: _activeTab,
      onTabChanged: (tab) => setState(() => _activeTab = tab),
    );
  }
}
