import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';

class LevelOption {
  final String value;
  final IconData icon;
  final String label;
  final String desc;

  const LevelOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.desc,
  });
}

const levels = [
  LevelOption(
      value: 'N5',
      icon: LucideIcons.sprout,
      label: 'N5 — 완전 초보',
      desc: '히라가나부터 시작'),
  LevelOption(
      value: 'N4',
      icon: LucideIcons.leaf,
      label: 'N4 — 기초',
      desc: '기본 문법과 단어를 알아요'),
  LevelOption(
      value: 'N3',
      icon: LucideIcons.treeDeciduous,
      label: 'N3 — 중급',
      desc: '일상 회화가 가능해요'),
  LevelOption(
      value: 'N2',
      icon: LucideIcons.bookOpen,
      label: 'N2 — 중상급',
      desc: '뉴스/소설을 읽을 수 있어요'),
  LevelOption(
      value: 'N1',
      icon: LucideIcons.crown,
      label: 'N1 — 상급',
      desc: '네이티브에 가까워요'),
];

class LevelStep extends StatelessWidget {
  final String? selectedLevel;
  final ValueChanged<String> onLevelSelected;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const LevelStep({
    super.key,
    required this.selectedLevel,
    required this.onLevelSelected,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppSizes.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '일본어, 얼마나 알고 계세요?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...levels.map((level) {
                final isSelected =
                    selectedLevel == level.value;
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () =>
                        onLevelSelected(level.value),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme
                                  .colorScheme.onSurface
                                  .withValues(
                                      alpha: 0.15),
                          width: 2,
                        ),
                        color: isSelected
                            ? theme.colorScheme.primary
                                .withValues(alpha: 0.1)
                            : null,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme
                                  .colorScheme.primary
                                  .withValues(
                                      alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              level.icon,
                              size: 20,
                              color: theme
                                  .colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  level.label,
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  level.desc,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme
                                        .colorScheme
                                        .onSurface
                                        .withValues(
                                            alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onBack,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('이전'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: selectedLevel != null
                            ? onNext
                            : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('다음'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
