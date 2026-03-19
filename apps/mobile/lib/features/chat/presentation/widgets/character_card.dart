import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/models/character_model.dart';

class CharacterCardWidget extends StatelessWidget {
  final CharacterListItem character;
  final int callCount;
  final bool isFavorite;
  final int userLevel;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const CharacterCardWidget({
    super.key,
    required this.character,
    required this.callCount,
    required this.isFavorite,
    required this.userLevel,
    required this.onTap,
    required this.onToggleFavorite,
  });

  bool get _isUnlocked {
    if (character.unlockCondition == null) return true;
    final required = int.tryParse(character.unlockCondition!);
    if (required == null) return true;
    return userLevel >= required;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unlocked = _isUnlocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        onTap: unlocked
            ? () {
                HapticService().selection();
                onTap();
              }
            : null,
        child: Opacity(
        opacity: unlocked ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.15),
                      colorScheme.tertiary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: !unlocked
                      ? Icon(LucideIcons.lock,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.5))
                      : character.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                character.avatarUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  character.avatarEmoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            )
                          : Text(
                              character.avatarEmoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                ),
              ),
              const SizedBox(width: AppSizes.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          character.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${character.nameJa})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      character.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unlocked
                          ? '${character.speechStyle} · ${character.targetLevel}${callCount > 0 ? ' · $callCount회 통화' : ''}'
                          : '레벨 ${character.unlockCondition} 이상 필요',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Favorite + Call
              if (unlocked) ...[
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticService().selection();
                    onToggleFavorite();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isFavorite ? LucideIcons.heart : LucideIcons.heart,
                      size: 18,
                      color: isFavorite
                          ? AppColors.hkRed(theme.brightness)
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.callAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.phone,
                      size: 16, color: AppColors.callAccent),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
