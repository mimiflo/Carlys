import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/debouncer.dart';
import '../../../../design_system/design_system.dart';
import '../../../exercises/domain/entities/exercise.dart' as catalog;
import '../../../exercises/presentation/providers/exercise_catalog_providers.dart';

/// Exercice choisi pour la prochaine série.
class PickedExercise {
  const PickedExercise({
    required this.name,
    this.exerciseId,
    this.measure = SetMeasure.repsAndWeight,
  });

  final String? exerciseId;
  final String name;

  /// Ce que ce mouvement se mesure EN : des répétitions et une charge, ou du
  /// temps et de la distance. Déduit du catalogue pour ouvrir la saisie sur
  /// la bonne unité — une course ne se compte pas en répétitions. Reste un
  /// DÉFAUT : la carte laisse basculer, parce qu'un gainage tenu au maximum
  /// se chronomètre même si le catalogue le classe en renforcement.
  final SetMeasure measure;
}

/// L'unité d'une série. Le catalogue la propose, la personne la tranche.
enum SetMeasure {
  repsAndWeight,
  timeAndDistance;

  static SetMeasure of(catalog.ExerciseKind kind) =>
      kind == catalog.ExerciseKind.cardio ? timeAndDistance : repsAndWeight;
}

/// Feuille de sélection d'exercice depuis le catalogue (avec recherche).
Future<PickedExercise?> showExercisePickerSheet(BuildContext context) {
  return showAppSheet<PickedExercise>(
    context,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _ExercisePicker(),
    ),
  );
}

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  final _searchController = TextEditingController();

  /// La frappe est RETENUE avant d'atteindre le réseau.
  ///
  /// `_search` est la clé d'une famille de `FutureProvider` qui appelle
  /// l'API : chaque caractère déclenchait une requête, soit dix-sept pour
  /// « Développé couché » dont seize jetées — et cette feuille s'ouvre en
  /// pleine séance, sur le réseau d'une salle de sport. La bibliothèque
  /// d'exercices, elle, débouncait depuis toujours ; c'est ici que ça
  /// manquait.
  final _debounce = Debouncer();
  String _search = '';

  /// Les résultats de la saisie PRÉCÉDENTE, gardés le temps de la suivante.
  ///
  /// Chaque saisie est une clé de famille distincte, donc un provider neuf
  /// qui part en `AsyncLoading` sans valeur : sans ce report, la liste
  /// disparaissait derrière un tourniquet à chaque recherche. On montre la
  /// liste précédente, grisée, plutôt que rien.
  List<catalog.ExerciseSummary>? _derniersResultats;

  @override
  void dispose() {
    _debounce.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final saisie = value.trim();
    _debounce.run(() {
      if (!mounted || saisie == _search) {
        return;
      }
      setState(() => _search = saisie);
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(exerciseSearchProvider(_search));
    final theme = Theme.of(context);

    // Report de la liste précédente : simple cache dérivé de la valeur
    // observée, sans `setState` — il ne provoque donc aucune reconstruction.
    final arrivees = results.valueOrNull;
    if (arrivees != null) {
      _derniersResultats = arrivees;
    }
    final affichables = arrivees ?? _derniersResultats;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choisir un exercice', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppSearchField(
              controller: _searchController,
              hint: 'Rechercher un exercice',
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _Resultats(
                exercices: affichables,
                enErreur: results.hasError,
                recherche: _search,
                onRetry: () => ref.invalidate(exerciseSearchProvider(_search)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Exercice libre (hors catalogue)',
              variant: AppButtonVariant.ghost,
              isExpanded: true,
              onPressed: () async {
                final name = await _promptFreeExercise(context);
                if (name != null && context.mounted) {
                  Navigator.of(context).pop(PickedExercise(name: name));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Les quatre états de la liste : erreur, chargement, vide, résultats.
///
/// L'état VIDE manquait : une recherche sans réponse rendait un `ListView`
/// de zéro élément, donc une zone blanche, sans un mot — alors que c'est le
/// cas le plus courant du sélecteur (une faute de frappe, un exercice hors
/// catalogue) et que le recours, « Exercice libre », est juste dessous.
class _Resultats extends StatelessWidget {
  const _Resultats({
    required this.exercices,
    required this.enErreur,
    required this.recherche,
    required this.onRetry,
  });

  final List<catalog.ExerciseSummary>? exercices;
  final bool enErreur;
  final String recherche;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liste = exercices;

    // L'erreur ne prend toute la place que si rien n'est montrable : avec une
    // liste précédente à l'écran, la remplacer par une pleine page d'erreur
    // ferait perdre à la personne ce qu'elle avait déjà trouvé.
    if (enErreur && liste == null) {
      return AppErrorState(
        title: 'Catalogue indisponible',
        message: 'Tu peux réessayer ou saisir un exercice libre.',
        onRetry: onRetry,
      );
    }
    if (liste == null) {
      return const AppLoadingIndicator();
    }
    if (liste.isEmpty) {
      return AppEmptyState(
        title: recherche.isEmpty
            ? 'Catalogue vide'
            : 'Aucun exercice pour « $recherche »',
        message: 'Saisis-le en exercice libre, juste en dessous.',
      );
    }

    return ListView.separated(
      itemCount: liste.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final exercise = liste[index];
        return ListTile(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          tileColor: theme.colorScheme.surfaceContainerHighest,
          title: Text(exercise.name),
          subtitle: exercise.primaryMuscleGroup == null
              ? null
              : Text(exercise.primaryMuscleGroup!.name),
          onTap: () => Navigator.of(context).pop(
            PickedExercise(
              exerciseId: exercise.id,
              name: exercise.name,
              measure: SetMeasure.of(exercise.kind),
            ),
          ),
        );
      },
    );
  }
}

Future<String?> _promptFreeExercise(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Exercice libre'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(hintText: 'Nom de l’exercice'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Annuler'),
        ),
        AppButton(
          label: 'Choisir',
          onPressed: () {
            final name = controller.text.trim();
            Navigator.of(dialogContext).pop(name.isEmpty ? null : name);
          },
        ),
      ],
    ),
  );
}
