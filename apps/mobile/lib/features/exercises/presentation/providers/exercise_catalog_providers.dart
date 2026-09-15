/// Les lectures DÉRIVÉES du catalogue d'exercices : elles n'ont pas d'état à
/// tenir, seulement un dépôt à interroger ou d'autres providers à combiner.
///
/// Elles vivaient à la suite de `ExerciseLibraryController`, qui, lui, tient
/// un état — liste accumulée, filtres, curseur. `features/README.md` prévoit
/// cette séparation depuis toujours : « `controllers/` : UN Notifier
/// Riverpod par fichier, et rien d'autre » ; « `providers/` : providers
/// dérivés qui ne portent aucun état ». C'est la première fonctionnalité à
/// ranger les siens ici.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../data/repositories/exercises_repository_impl.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercises_repository.dart';

/// L'utilisateur a demandé le catalogue ENTIER depuis la grille.
///
/// État de navigation, pas de filtre : « aucun groupe » veut dire deux choses
/// opposées — on n'a pas encore choisi (grille), ou on a choisi de tout voir
/// (liste). Le domaine n'a pas à porter cette nuance, l'écran si.
final exerciseCatalogueOpenProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

/// Référentiel des groupes musculaires (pour les filtres).
final muscleGroupsProvider = FutureProvider.autoDispose<List<MuscleGroupRef>>((
  ref,
) {
  return ref.watch(exercisesRepositoryProvider).muscleGroups();
});

/// Fiche détaillée d'un exercice.
final exerciseDetailProvider = FutureProvider.autoDispose
    .family<ExerciseDetail, String>((ref, idOrSlug) {
      return ref.watch(exercisesRepositoryProvider).byIdOrSlug(idOrSlug);
    });

/// Une recherche PONCTUELLE du catalogue, sans accumulation ni pagination —
/// la feuille « Choisir un exercice » ouverte en séance et dans l'éditeur de
/// modèle. [ExerciseLibraryController] reste l'écran de bibliothèque, qui
/// empile ses pages ; ici on ne montre qu'une liste courte, jetée à la
/// fermeture de la feuille.
///
/// Vit ICI et non dans la feuille qui l'emploie : c'était le SEUL provider
/// déclaré dans un fichier de `widgets/` de tout le dépôt, et il y importait
/// l'implémentation du dépôt — « ne jamais faire d'appel API directement
/// depuis un widget » (CLAUDE.md, `features/README.md`). La feuille ne fait
/// plus que l'observer.
final exerciseSearchProvider = FutureProvider.autoDispose
    .family<List<ExerciseSummary>, String>((ref, search) async {
      final page = await ref
          .watch(exercisesRepositoryProvider)
          .list(
            filters: ExercisesFilters(search: search.isEmpty ? null : search),
          );
      return page.items;
    });

/// Clé d'un exercice pour la sélection de ses records : l'API historique
/// rattache un record par identifiant quand il existe, par nom sinon.
typedef ExerciseRecordsKey = ({String id, String name});

/// Records personnels de l'utilisateur sur un exercice donné (liste vide
/// tant que les records ne sont pas chargés — jamais de valeur inventée).
final exerciseRecordsProvider = Provider.autoDispose
    .family<List<PersonalRecordEntry>, ExerciseRecordsKey>((ref, key) {
      final all =
          ref.watch(personalRecordsProvider).valueOrNull ??
          const <PersonalRecordEntry>[];
      return all
          .where(
            (record) =>
                record.exerciseId == key.id || record.exerciseName == key.name,
          )
          .toList();
    });
