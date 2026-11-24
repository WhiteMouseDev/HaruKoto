import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'my_settings_group.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MySettingsGroup(
      label: '고객센터',
      rows: [
        ListTile(
          leading: Icon(LucideIcons.mail,
              size: 20, color: theme.colorScheme.primary),
          title: const Text('문의하기', style: TextStyle(fontSize: 14)),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () =>
              launchUrl(Uri.parse('mailto:whitemousedev@whitemouse.dev')),
        ),
        ListTile(
          leading: Icon(LucideIcons.fileText,
              size: 20, color: theme.colorScheme.primary),
          title: const Text('이용약관', style: TextStyle(fontSize: 14)),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => context.push('/legal/terms'),
        ),
        ListTile(
          leading: Icon(LucideIcons.shield,
              size: 20, color: theme.colorScheme.primary),
          title: const Text('개인정보 처리방침', style: TextStyle(fontSize: 14)),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => context.push('/legal/privacy'),
        ),
      ],
    );
  }
}
