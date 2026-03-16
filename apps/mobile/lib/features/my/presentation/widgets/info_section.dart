import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/sizes.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '정보',
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
                leading: Icon(LucideIcons.fileText,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('이용약관', style: TextStyle(fontSize: 14)),
                trailing: Icon(LucideIcons.chevronRight,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                onTap: () => context.push('/legal/terms'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(LucideIcons.shield,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('개인정보처리방침', style: TextStyle(fontSize: 14)),
                trailing: Icon(LucideIcons.chevronRight,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                onTap: () => context.push('/legal/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(LucideIcons.mail,
                    size: 20, color: theme.colorScheme.primary),
                title: const Text('문의하기', style: TextStyle(fontSize: 14)),
                trailing: Icon(LucideIcons.chevronRight,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                onTap: () => launchUrl(
                  Uri.parse('mailto:whitemousedev@whitemouse.dev'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
