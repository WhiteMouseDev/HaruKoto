import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'my_settings_group.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return MySettingsGroup(
      label: '고객센터',
      rows: [
        ListTile(
          leading: const MySettingsIcon('contact'),
          title: const Text('문의하기', style: TextStyle(fontSize: 14)),
          trailing: const MySettingsChevron(),
          onTap: () =>
              launchUrl(Uri.parse('mailto:whitemousedev@whitemouse.dev')),
        ),
        ListTile(
          leading: const MySettingsIcon('terms'),
          title: const Text('이용약관', style: TextStyle(fontSize: 14)),
          trailing: const MySettingsChevron(),
          onTap: () => context.push('/legal/terms'),
        ),
        ListTile(
          leading: const MySettingsIcon('privacy'),
          title: const Text('개인정보 처리방침', style: TextStyle(fontSize: 14)),
          trailing: const MySettingsChevron(),
          onTap: () => context.push('/legal/privacy'),
        ),
      ],
    );
  }
}
