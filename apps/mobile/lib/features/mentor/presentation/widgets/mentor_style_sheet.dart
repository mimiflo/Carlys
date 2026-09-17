import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_style.dart';
import '../controllers/mentor_controllers.dart';

/// Feuille « La voix du Mentor » : quatre styles, un choix, modifiable à
/// tout moment. La sélection affichée vient de `AuthUser.mentorStyle` (une
/// seule source de vérité) ; choisir écrit au serveur puis rafraîchit
/// l'utilisateur, et un échec s'affiche sans rien changer.
Future<void> showMentorStyleSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorStyleSheet());
}

class _MentorStyleSheet extends ConsumerWidget {
  const _MentorStyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentMentorStyleProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'La voix du Mentor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Comment il te parle : le fond ne change pas, le ton oui. '
            'Essaie, change quand tu veux.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final style in MentorStyle.values) ...[
            _StyleRow(
              style: style,
              current: style == current,
              onChoose: () => _choisir(context, ref, style),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  Future<void> _choisir(
    BuildContext context,
    WidgetRef ref,
    MentorStyle style,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(mentorActionsProvider).chooseStyle(style);
      if (navigator.mounted) {
        navigator.pop();
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Le Mentor parlera en ${style.label}.')),
      );
    } on AppException catch (exception) {
      messenger.showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }
}

/// Une voix : son nom, ce qu'elle change, et l'état « choisie ».
class _StyleRow extends StatelessWidget {
  const _StyleRow({
    required this.style,
    required this.current,
    required this.onChoose,
  });

  final MentorStyle style;
  final bool current;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: current,
      label:
          '${style.label}. ${style.description}'
          '${current ? ' Voix actuelle.' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onChoose,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(
                color: current ? AppColors.primaryLight : AppColors.darkBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      style.description,
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (current) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  AppIcons.checkCircle,
                  size: 18,
                  color: AppColors.primaryLight,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
