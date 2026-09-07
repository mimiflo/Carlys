import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Une séance dont l'envoi a été mis de côté, et le geste pour le relancer.
///
/// Sans ce bouton, une opération mise de côté (trop d'erreurs serveur
/// d'affilée) n'avait qu'un seul rejeu : l'ouverture suivante de
/// l'application. Dans une session donnée, l'utilisateur voyait l'échec sans
/// pouvoir rien en faire — il fallait tuer et relancer l'application.
class WorkoutRetrySyncCard extends ConsumerStatefulWidget {
  const WorkoutRetrySyncCard({required this.session, super.key});

  final WorkoutInfo session;

  @override
  ConsumerState<WorkoutRetrySyncCard> createState() =>
      _WorkoutRetrySyncCardState();
}

class _WorkoutRetrySyncCardState extends ConsumerState<WorkoutRetrySyncCard> {
  static const _logger = AppLogger('WorkoutRetrySyncCard');

  /// Message montré quand l'échec n'a pas de cause présentable.
  static const _genericFailure =
      'Impossible de réessayer pour le moment. Retente dans un instant.';

  bool _busy = false;
  String? _error;

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(workoutActionsProvider).retryFailedSync(widget.session.id);
    } on AppException catch (exception) {
      // Hors ligne ou serveur indisponible : la séance reste en échec, le
      // geste reste proposé.
      _logger.warning('Rejeu impossible', error: exception);
      if (mounted) {
        setState(() => _error = exception.message);
      }
    } catch (error) {
      // Attrape TOUT : une base fermée sous le rejeu signale par une
      // `Error`, qu'un `on AppException` laisserait passer — l'écran
      // resterait alors bloqué en chargement, sans rien dire.
      _logger.error('Rejeu impossible', error: error);
      if (mounted) {
        setState(() => _error = _genericFailure);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;

    return AppCard(
      semanticLabel: 'Séance non synchronisée',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(AppIcons.error, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Pas encore envoyée au serveur',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Le serveur n’a pas pu enregistrer cette séance. Rien n’est '
            'perdu : elle est gardée sur cet appareil et repartira toute '
            'seule à la prochaine ouverture. Tu peux aussi réessayer tout de '
            'suite.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Réessayer la synchronisation',
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            isLoading: _busy,
            onPressed: _busy ? null : _retry,
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
