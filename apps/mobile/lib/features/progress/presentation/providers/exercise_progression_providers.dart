import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/progress.dart';

/// La progression sur UN exercice : ses séances et ses records, ensemble.
///
/// Dérivé et sans état propre, donc `providers/` et non `controllers/` :
/// il n'y a rien à piloter ici, seulement une lecture paramétrée.
///
/// `autoDispose` parce que l'écran est POUSSÉ : sans lui, chaque exercice
/// consulté garderait sa réponse en mémoire pour le reste de la session.
final exerciseProgressionProvider = FutureProvider.autoDispose
    .family<ExerciseProgressionEntity, String>((ref, exerciseId) {
      return ref
          .watch(progressRepositoryProvider)
          .exerciseProgression(exerciseId);
    });
