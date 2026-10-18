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

import '../../../authentication/presentation/providers/keep_for_account.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
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

/// Le catalogue ne bouge pas d'une ouverture à l'autre : ses lectures sont
/// GARDÉES ce temps-là après avoir été lues ([keepForAccount]). En séance,
/// la feuille « Choisir un exercice » s'ouvre à chaque mouvement ajouté —
/// cinq ouvertures faisaient cinq requêtes, et cinq indicateurs de
/// chargement (`exercise_catalog_keep_alive_test.dart`).
const Duration catalogKeepAlive = Duration(minutes: 10);

/// Référentiel des groupes musculaires (pour les filtres).
final muscleGroupsProvider = FutureProvider.autoDispose<List<MuscleGroupRef>>((
  ref,
) {
  final repository = ref.watch(exercisesRepositoryProvider);
  return keepForAccount(
    ref,
    repository.muscleGroups,
    duration: catalogKeepAlive,
  );
});

/// Référentiel du matériel — filtres du catalogue ET matériel déclaré au
/// profil d'entraînement : une seule taxonomie, jamais deux listes.
final equipmentCatalogProvider = FutureProvider.autoDispose<List<EquipmentRef>>(
  (ref) {
    final repository = ref.watch(exercisesRepositoryProvider);
    return keepForAccount(
      ref,
      repository.equipment,
      duration: catalogKeepAlive,
    );
  },
);

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
    .family<List<ExerciseSummary>, String>((ref, search) {
      final repository = ref.watch(exercisesRepositoryProvider);
      Future<List<ExerciseSummary>> read() async {
        final page = await repository.list(
          filters: ExercisesFilters(search: search.isEmpty ? null : search),
        );
        return page.items;
      }

      // Seule la liste d'ouverture, sans recherche, est gardée : celle que
      // chaque ouverture relit. Une recherche tapée reste jetée.
      return search.isEmpty
          ? keepForAccount(ref, read, duration: catalogKeepAlive)
          : read();
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
