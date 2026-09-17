import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_word.dart';
import '../controllers/mentor_controllers.dart';

/// L'image de chaque voix — présentation pure, le domaine n'en sait rien.
IconData mentorVoiceIcon(MentorStyle style) => switch (style) {
  MentorStyle.bienveillant => AppIcons.voiceBienveillant,
  MentorStyle.exigeant => AppIcons.voiceExigeant,
  MentorStyle.athlete => AppIcons.voiceAthlete,
  MentorStyle.philosophe => AppIcons.voicePhilosophe,
};

/// Feuille « La voix du Mentor » : quatre styles, un choix, modifiable à
/// tout moment. La sélection affichée vient de `AuthUser.mentorStyle` (une
/// seule source de vérité) ; choisir écrit au serveur puis rafraîchit
/// l'utilisateur, et un échec s'affiche sans rien changer. Chaque carte
/// fait ENTENDRE sa voix : le premier mot de son catalogue, cité tel quel.
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

/// Une voix : son image, son nom, ce qu'elle change, un mot d'elle — et
/// l'état « choisie » (bordure et fond accentués, coche).
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
    final exemple = mentorWordCatalog[style]!.first;

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
            color: current
                ? AppColors.primaryCardSoft
                : AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(
                color: current ? AppColors.primaryLight : AppColors.darkBorder,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryBadgeBg,
                    ),
                    child: Icon(
                      mentorVoiceIcon(style),
                      size: 18,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      style.label,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  if (current)
                    const Icon(
                      AppIcons.checkCircle,
                      size: 18,
                      color: AppColors.primaryLight,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                style.description,
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    AppIcons.quote,
                    size: 14,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '« $exemple »',
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
