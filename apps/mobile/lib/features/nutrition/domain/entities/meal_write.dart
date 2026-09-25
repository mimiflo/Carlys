/// Ce que l'appareil ÉCRIT d'un repas, à la création comme à la correction.
///
/// Un repas est SAISI À LA MAIN (ses totaux sont ce que la personne a tapé)
/// ou COMPOSÉ (ses totaux se calculent depuis ses aliments) — jamais les
/// deux : le serveur refuse un corps qui porterait des aliments ET des
/// totaux, pour qu'aucun des deux ne soit ignoré en silence. D'où un
/// contenu à trois formes, qu'on ne peut pas mélanger par construction.
library;

import 'meal_entry.dart';

/// Tout ce qui s'écrit d'un repas.
///
/// L'objet est COMPLET plutôt qu'un fragment : l'écran montre l'entrée
/// entière et envoie ce que la personne a sous les yeux. Vider la case
/// « Protéines » veut alors dire « on ne sait plus », et cela doit
/// s'écrire.
class MealWrite {
  const MealWrite({
    required this.name,
    required this.eatenAt,
    required this.content,
    this.moment,
  });

  final String name;

  /// L'instant du repas, tel que la personne le dit ; envoyé en UTC.
  final DateTime eatenAt;
  final MealMoment? moment;
  final MealContent content;

  /// La même écriture, pour ÉCRASER un repas dont on ignore l'état sur le
  /// serveur (une création dont la réponse s'est perdue) : saisi à la main,
  /// il y retire toute composition, qu'il en ait une ou non — le serveur
  /// refuserait sinon des totaux posés sur un repas composé.
  MealWrite overwriting() {
    final manual = content;
    if (manual is! ManualMealContent || manual.clearsComposition) {
      return this;
    }
    return MealWrite(
      name: name,
      eatenAt: eatenAt,
      moment: moment,
      content: ManualMealContent(
        kcal: manual.kcal,
        proteinG: manual.proteinG,
        carbsG: manual.carbsG,
        fatG: manual.fatG,
        quantity: manual.quantity,
        quantityUnit: manual.quantityUnit,
        clearsComposition: true,
      ),
    );
  }
}

/// Les valeurs d'un repas : saisies, composées, ou laissées telles quelles.
sealed class MealContent {
  const MealContent();
}

/// Un repas SAISI À LA MAIN : les calories (obligatoires), les macros et la
/// quantité (facultatives, `null` = « on ne sait pas »).
///
/// La quantité est DESCRIPTIVE : elle ne multiplie ni [kcal] ni les macros,
/// qui restent le total du repas. Elle va par paire avec son unité.
final class ManualMealContent extends MealContent {
  const ManualMealContent({
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.quantity,
    this.quantityUnit,
    this.clearsComposition = false,
  });

  final int kcal;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final double? quantity;
  final MealQuantityUnit? quantityUnit;

  /// Vrai quand le repas ÉTAIT composé et que la personne en a retiré le
  /// dernier aliment : la correction retire la composition
  /// (`components: []`), et le repas redevient saisi à la main avec ces
  /// valeurs.
  final bool clearsComposition;
}

/// Un repas COMPOSÉ : la liste de ses aliments, qui REMPLACE la précédente.
/// Le serveur calcule kcal, macros et quantité ; aucun total ne part avec.
///
/// La liste n'est jamais vide : un repas sans aliment est SAISI
/// ([ManualMealContent]), et c'est l'état de l'écran qui choisit la forme.
final class ComposedMealContent extends MealContent {
  const ComposedMealContent(this.components);

  final List<MealComponentInput> components;
}

/// La composition d'un repas déjà composé, INCHANGÉE : seuls le nom, le
/// moment et l'heure se corrigent. Rien des aliments ni des totaux ne part,
/// et le serveur garde l'instantané de chaque ligne. N'a de sens qu'en
/// correction : un repas neuf n'a encore rien à garder.
final class KeptCompositionContent extends MealContent {
  const KeptCompositionContent();
}
