import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';

class _FeatureRow {
  final String name;
  final bool free;
  final bool premium;

  const _FeatureRow({
    required this.name,
    required this.free,
    required this.premium,
  });
}

const _features = [
  _FeatureRow(name: 'JLPT 단어/문법 학습', free: true, premium: true),
  _FeatureRow(name: '퀴즈 무제한', free: true, premium: true),
  _FeatureRow(name: '히라가나/가타카나 학습', free: true, premium: true),
  _FeatureRow(name: 'AI 채팅 (일 3회)', free: true, premium: false),
  _FeatureRow(name: 'AI 채팅 무제한', free: false, premium: true),
  _FeatureRow(name: 'AI 음성통화 (일 1회)', free: true, premium: false),
  _FeatureRow(name: 'AI 음성통화 무제한', free: false, premium: true),
  _FeatureRow(name: '모든 AI 캐릭터 해금', free: false, premium: true),
  _FeatureRow(name: '상세 학습 리포트', free: false, premium: true),
  _FeatureRow(name: '광고 제거', free: false, premium: true),
];

class FeatureComparison extends StatelessWidget {
  const FeatureComparison({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '기능',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '무료',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '프리미엄',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          ...List.generate(_features.length, (i) {
            final feature = _features[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: i < _features.length - 1
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.06),
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      feature.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: feature.free
                          ? Icon(
                              LucideIcons.check,
                              size: 16,
                              color: theme.colorScheme.primary,
                            )
                          : Icon(
                              LucideIcons.x,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2),
                            ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: feature.premium
                          ? Icon(
                              LucideIcons.check,
                              size: 16,
                              color: theme.colorScheme.primary,
                            )
                          : Icon(
                              LucideIcons.x,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2),
                            ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
