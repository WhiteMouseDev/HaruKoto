import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';

class NicknameStep extends StatelessWidget {
  final String nickname;
  final ValueChanged<String> onNicknameChanged;
  final VoidCallback onNext;

  const NicknameStep({
    super.key,
    required this.nickname,
    required this.onNicknameChanged,
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
                '반가워요!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '어떻게 불러드릴까요?',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: onNicknameChanged,
                controller:
                    TextEditingController(text: nickname)
                      ..selection =
                          TextSelection.fromPosition(
                        TextPosition(
                            offset: nickname.length),
                      ),
                maxLength: 20,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '닉네임을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: nickname.trim().isNotEmpty
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
            ],
          ),
        ),
      ),
    );
  }
}
