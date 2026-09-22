/// NOTER UN REPAS : le chemin, partagé par tous ceux qui l'ouvrent.
///
/// Le geste vivait en entier dans `meal_journal_section.dart`, où il était né.
/// L'accueil en a eu besoin à son tour — sa tuile de calories montre le total
/// du jour, et c'est là que naît l'envie de le nourrir — et le recopier aurait
/// donné deux chemins pour un seul acte. Deux copies d'un geste d'écriture
/// finissent par diverger sur ce qui compte le moins et se voit le plus : le
/// message d'échec, la portée du journal, le champ qu'on oublie de passer.
///
/// Il vit donc ici, à la racine de `presentation/`, parce qu'il n'appartient
/// ni au journal ni à l'accueil : c'est un chemin de la FONCTIONNALITÉ.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/server_gesture.dart';
import 'controllers/nutrition_controllers.dart';
import 'widgets/add_meal_sheet.dart';

/// Ouvre la feuille de saisie, puis enregistre ce qu'elle rend.
///
/// [day] fixe le jour du repas — le journal consulte l'histoire, et un repas
/// ajouté depuis le 12 septembre doit atterrir au 12 septembre. Nul, la
/// feuille propose aujourd'hui, ce qui est le cas de l'accueil.
///
/// [scope] nomme l'appelant dans les journaux : deux portes vers le même
/// geste, et une panne doit dire par laquelle on est passé.
///
/// LE FILET EST OBLIGATOIRE, et c'est la raison d'être de cette fonction. Le
/// journal vit sur le SERVEUR : un ajout refusé doit se voir, puisque la
/// feuille s'est déjà refermée et que la liste ne bouge pas — rien ne
/// distinguerait alors « refusé » de « déjà enregistré ».
Future<void> noteUnRepas(
  BuildContext context,
  WidgetRef ref, {
  DateTime? day,
  required String scope,
}) async {
  final draft = await showMealSheet(context, day: day);
  if (draft == null || !context.mounted) {
    return;
  }
  await runServerGesture(context, () async {
    await ref
        .read(nutritionActionsProvider)
        .addMeal(
          name: draft.name,
          kcal: draft.kcal,
          eatenAt: draft.eatenAt,
          quantity: draft.quantity,
          quantityUnit: draft.quantityUnit,
          proteinG: draft.proteinG,
          carbsG: draft.carbsG,
          fatG: draft.fatG,
        );
    return null;
  }, scope: scope);
}
