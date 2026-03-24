import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../providers/chat_provider.dart';
import 'voice_call_launch.dart';
import 'widgets/character_card.dart';

class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final charactersAsync = ref.watch(charactersProvider);
    final statsAsync = ref.watch(characterStatsProvider);
    final favoritesAsync = ref.watch(characterFavoritesProvider);
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text(
          '연락처',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: charactersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '캐릭터를 불러올 수 없습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(charactersProvider),
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (characters) {
          final stats = statsAsync.when(
            data: (d) => d,
            loading: () => <String, int>{},
            error: (_, __) => <String, int>{},
          );
          final favorites = favoritesAsync.when(
            data: (d) => d,
            loading: () => <String>{},
            error: (_, __) => <String>{},
          );
          const levels = {'N5': 1, 'N4': 2, 'N3': 3, 'N2': 4, 'N1': 5};
          final userLevel = levels[jlptLevel] ?? 1;

          // Sort: favorites first, then by order
          final sorted = [...characters]..sort((a, b) {
              final aFav = favorites.contains(a.id) ? 1 : 0;
              final bFav = favorites.contains(b.id) ? 1 : 0;
              if (aFav != bFav) return bFav - aFav;
              return a.order - b.order;
            });

          return ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              ...sorted.map((char) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: CharacterCardWidget(
                      character: char,
                      callCount: stats[char.id] ?? 0,
                      isFavorite: favorites.contains(char.id),
                      userLevel: userLevel,
                      onTap: () {
                        openVoiceCallPage(
                          context,
                          characterId: char.id,
                          characterName: char.name,
                          avatarUrl: char.avatarUrl,
                        );
                      },
                      onToggleFavorite: () async {
                        final repo = ref.read(chatRepositoryProvider);
                        await repo.toggleFavorite(char.id);
                        ref.invalidate(characterFavoritesProvider);
                      },
                    ),
                  )),
              const SizedBox(height: AppSizes.md),
              Text(
                '레벨이 올라가면 새로운 캐릭터가 해금됩니다',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),
            ],
          );
        },
      ),
    );
  }
}
