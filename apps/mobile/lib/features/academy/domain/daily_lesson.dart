/// Le rang du jour dans l'année, pour désigner la leçon du jour.
///
/// **Pourquoi ce n'est pas une soustraction de dates.** La première version
/// écrivait `now.difference(DateTime(now.year)).inDays` : une DURÉE écoulée,
/// pas un jour de calendrier. Or une durée ne compte pas les jours quand
/// l'heure change. Mesuré en Europe/Paris pour 2026 (heure d'été le 29 mars) :
///
/// | instant local     | durée écoulée | jour civil |
/// | ----------------- | ------------- | ---------- |
/// | 29 mars 00 h 30   | 87            | 87         |
/// | 30 mars 00 h 30   | **87**        | 88         |
/// | 30 mars 01 h 30   | 88            | 88         |
/// | 31 mars 00 h 30   | **88**        | 89         |
///
/// Deux conséquences, et la seconde dure des mois : le 30 mars au matin, la
/// question servie était celle de la veille, déjà répondue et affichée comme
/// telle ; et jusqu'au retour à l'heure d'hiver, la question du jour changeait
/// à 01 h 30 du matin au lieu de minuit.
///
/// Le calcul passe donc par des instants **UTC construits avec les champs de
/// calendrier locaux**. En UTC un jour fait exactement 24 heures, aucun
/// changement d'heure ne s'y produit : la soustraction redevient un comptage
/// de jours, et le résultat ne dépend plus que de l'année, du mois et du
/// quantième.
int dayOfYearIndex(DateTime local) {
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(local.year)).inDays;
}
