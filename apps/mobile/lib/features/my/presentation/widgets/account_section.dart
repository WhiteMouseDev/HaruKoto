import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class AccountSection extends StatelessWidget {
  final VoidCallback onLogout;
  final bool loggingOut;
  final VoidCallback onDeleteAccount;

  const AccountSection({
    super.key,
    required this.onLogout,
    required this.loggingOut,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '계정',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  LucideIcons.logOut,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                title: Text(
                  loggingOut ? '로그아웃 중...' : '로그아웃',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: loggingOut ? null : onLogout,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  LucideIcons.trash2,
                  size: 20,
                  color: AppColors.error(brightness),
                ),
                title: Text(
                  '회원 탈퇴',
                  style: TextStyle(fontSize: 14, color: AppColors.error(brightness)),
                ),
                onTap: () => _showDeleteDialog(context),
              ),
            ],
          ),
        ),

        // Version
        const SizedBox(height: 16),
        Center(
          child: Text(
            'v0.1.0',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('회원 탈퇴'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '탈퇴하면 다음 데이터가 모두 삭제되며 복구할 수 없습니다.',
                  ),
                  const SizedBox(height: 12),
                  const Text('- 학습 진행 상황', style: TextStyle(fontSize: 13)),
                  const Text('- 퀴즈 기록', style: TextStyle(fontSize: 13)),
                  const Text('- AI 회화 기록', style: TextStyle(fontSize: 13)),
                  const Text('- 단어장', style: TextStyle(fontSize: 13)),
                  const Text('- 업적', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text(
                    '확인을 위해 "탈퇴"를 입력해주세요.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: '탈퇴',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    controller.dispose();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: controller.text == '탈퇴'
                      ? () {
                          Navigator.pop(context);
                          controller.dispose();
                          onDeleteAccount();
                        }
                      : null,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error(Theme.of(context).brightness)),
                  child: const Text('회원 탈퇴'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
