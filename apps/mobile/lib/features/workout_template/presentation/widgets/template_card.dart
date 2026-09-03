import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/workout_template.dart';

/// Carte d'un modèle dans « Mes modèles » : identité du programme, faits
/// chiffrés, état de synchronisation et l'unique action accent — « Lancer ».
///
/// La carte entière ouvre l'éditeur ; l'appui long propose de supprimer.
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    required this.template,
    required this.onOpen,
    required this.onStart,
    required this.onDelete,
    super.key,
  });

  final WorkoutTemplateInfo template;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  /// Maquette : padding interne des grandes cartes (20).
  static const double _padding = AppSpacing.md + AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    final facts = _facts();

    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: GestureDetector(
        onLongPress: () => _confirmDelete(context),
        child: Material(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardMainAll,
          child: InkWell(
            onTap: onOpen,
            borderRadius: AppRadius.cardMainAll,
            child: Ink(
              decoration: const BoxDecoration(
                borderRadius: AppRadius.cardMainAll,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.darkBorder),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Title(template: template),
                    if (template.previewExerciseNames.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        template.previewExerciseNames.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body
                            .copyWith(color: AppColors.darkTextSecondary),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final fact in facts)
                          AppPill(label: fact, mono: true),
                        ..._syncPills(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StartButton(
                      onPressed: onStart,
                      semanticLabel: 'Lancer le modèle ${template.name}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Faits chiffrés du modèle — mono tabulaire, jamais de nombre brut.
  List<String> _facts() {
    final exercises = template.exercisesCount;
    final sets = template.plannedSetsCount;
    final duration = template.estimatedDurationMinutes;
    final lastUsedAt = template.lastUsedAt;

    return [
      '${formatThousands(exercises)} exercice${exercises > 1 ? 's' : ''}',
      '${formatThousands(sets)} série${sets > 1 ? 's' : ''}',
      if (duration != null) '${formatThousands(duration)} min',
      if (lastUsedAt != null) formatRelativeDayMono(lastUsedAt),
    ];
  }

  /// Hors ligne n'est pas une erreur : la carte s'affiche normalement, elle
  /// signale seulement que l'enregistrement n'est pas encore acquitté.
  List<Widget> _syncPills() {
    return switch (template.syncState) {
      LocalSyncState.synced => const [],
      LocalSyncState.pending => const [
          AppPill(label: 'En attente', tone: AppPillTone.primary),
        ],
      LocalSyncState.failed => const [
          AppPill(label: 'Non synchronisé', tone: AppPillTone.primary),
        ],
    };
  }

  String _semanticLabel() {
    final exercises = template.exercisesCount;
    final sets = template.plannedSetsCount;
    return 'Modèle ${template.name}, '
        '${formatThousands(exercises)} exercice${exercises > 1 ? 's' : ''}, '
        '${formatThousands(sets)} série${sets > 1 ? 's' : ''} prévue'
        '${sets > 1 ? 's' : ''}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer « ${template.name} » ?'),
        content: const Text(
          'Le modèle disparaît de tes programmes. Les séances déjà '
          'réalisées avec lui ne bougent pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete();
    }
  }
}

/// Nom du modèle et chevron d'ouverture de l'éditeur.
class _Title extends StatelessWidget {
  const _Title({required this.template});

  final WorkoutTemplateInfo template;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            template.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading
                .copyWith(color: AppColors.darkTextPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(
          AppIcons.chevronRight,
          size: 20,
          color: AppColors.darkTextTertiary,
        ),
      ],
    );
  }
}

/// Unique action accent de la carte : lancer le modèle.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed, required this.semanticLabel});

  final VoidCallback onPressed;
  final String semanticLabel;

  /// Géométrie de la maquette : icône 19, halo `0 12px 30px -12px`.
  static const double _iconSize = 19;
  static const double _glowBlur = 30;
  static const double _glowSpread = -12;
  static const double _glowOffset = 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.buttonAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.7),
              blurRadius: _glowBlur,
              spreadRadius: _glowSpread,
              offset: const Offset(0, _glowOffset),
            ),
          ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.darkBackground,
            textStyle:
                AppTypography.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.play, size: _iconSize),
              SizedBox(width: AppSpacing.xs),
              Text('Lancer'),
            ],
          ),
        ),
      ),
    );
  }
}
