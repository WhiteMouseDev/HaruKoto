import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';
import 'option_button.dart';

class KanaStep extends StatelessWidget {
  final bool showKana;
  final ValueChanged<bool> onShowKanaChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const KanaStep({
    super.key,
    required this.showKana,
    required this.onShowKanaChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
                '히라가나/가타카나부터 배워볼까요?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '일본어의 기초 문자를 먼저 학습할 수 있어요',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              OptionButton(
                selected: showKana,
                title: '네, 기초부터 배울래요',
                subtitle: '히라가나/가타카나부터 차근차근 시작해요',
                onTap: () => onShowKanaChanged(true),
              ),
              const SizedBox(height: 10),
              OptionButton(
                selected: !showKana,
                title: '건너뛸게요',
                subtitle: '이미 가나를 알고 있어요',
                onTap: () => onShowKanaChanged(false),
              ),
              const SizedBox(height: 16),
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
                        onPressed: onNext,
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
