import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'my_settings_group.dart';

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MySettingsGroup(
          label: '계정',
          rows: [
            ListTile(
              leading: const MySettingsIcon('logout'),
              title: Text(
                loggingOut ? '로그아웃 중...' : '로그아웃',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const MySettingsChevron(),
              onTap: loggingOut ? null : onLogout,
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => _showDeleteDialog(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 20),
              foregroundColor: brightness == Brightness.light
                  ? AppColors.redesignMutedForeground
                  : theme.colorScheme.onSurfaceVariant,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: const Text('회원탈퇴', semanticsLabel: '회원 탈퇴'),
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed == true && context.mounted) onDeleteAccount();
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('회원 탈퇴'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('탈퇴하면 다음 데이터가 모두 삭제되며 복구할 수 없습니다.'),
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
            controller: _controller,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _controller.text == '탈퇴'
              ? () => Navigator.pop(context, true)
              : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error(Theme.of(context).brightness),
          ),
          child: const Text('회원 탈퇴'),
        ),
      ],
    );
  }
}
