import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Une séance clôturée ici ET, autrement, sur un autre appareil : le
/// serveur a refusé la clôture locale, c'est à l'utilisateur de trancher.
///
/// Deux gestes, rien de plus : prendre la version du serveur (elle remplace
/// la copie locale) ou garder la sienne (renvoyée telle quelle). Aucune
/// série n'est perdue dans un cas comme dans l'autre.
class WorkoutConflictCard extends ConsumerStatefulWidget {
  const WorkoutConflictCard({required this.session, super.key});

  final WorkoutInfo session;

  @override
  ConsumerState<WorkoutConflictCard> createState() =>
      _WorkoutConflictCardState();
}

class _WorkoutConflictCardState extends ConsumerState<WorkoutConflictCard> {
  static const _logger = AppLogger('WorkoutConflictCard');

  WorkoutConflictResolution? _inFlight;
  String? _error;

  Future<void> _resolve(WorkoutConflictResolution resolution) async {
    setState(() {
      _inFlight = resolution;
      _error = null;
    });
    try {
      await ref
          .read(workoutActionsProvider)
          .resolveConflict(widget.session.id, resolution);
    } on AppException catch (exception) {
      // Hors ligne ou serveur indisponible : rien n'a été modifié, le
      // choix reste proposé.
      _logger.warning('Conflit non résolu', error: exception);
      if (mounted) {
        setState(() => _error = exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _inFlight = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;
    final busy = _inFlight != null;

    return AppCard(
      semanticLabel: 'Séance en conflit de synchronisation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(AppIcons.error, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Clôturée autrement sur un autre appareil',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ici, tu l’as marquée « ${widget.session.status.label.toLowerCase()} » ; '
            'le serveur l’a enregistrée avec une autre issue. Choisis la '
            'version à garder : celle du serveur remplace ta copie locale, '
            'la tienne est renvoyée telle quelle. Tes séries sont conservées '
            'dans les deux cas.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Prendre la version du serveur',
            isExpanded: true,
            isLoading: _inFlight == WorkoutConflictResolution.takeServer,
            onPressed: busy
                ? null
                : () => _resolve(WorkoutConflictResolution.takeServer),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Garder ma version',
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            isLoading: _inFlight == WorkoutConflictResolution.keepLocal,
            onPressed: busy
                ? null
                : () => _resolve(WorkoutConflictResolution.keepLocal),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
