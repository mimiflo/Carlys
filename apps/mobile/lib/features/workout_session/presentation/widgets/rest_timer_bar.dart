import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/workout_controllers.dart';

/// Bandeau de minuteur de repos, affiché au-dessus des actions de séance.
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    if (timer == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final minutes = timer.remaining.inMinutes;
    final seconds = timer.remaining.inSeconds % 60;

    return Semantics(
      liveRegion: true,
      label: 'Repos restant',
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(AppIcons.timer, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Repos : $minutes:${seconds.toString().padLeft(2, '0')}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  LinearProgressIndicator(
                    value: timer.progress,
                    borderRadius: AppRadius.fullAll,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(restTimerProvider.notifier).stop(),
              child: const Text('Passer'),
            ),
          ],
        ),
      ),
    );
  }
}
