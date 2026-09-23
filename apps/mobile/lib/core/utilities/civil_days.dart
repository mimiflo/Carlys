/// JOURS CIVILS : compter des jours de calendrier, pas des tranches de
/// vingt-quatre heures.
///
/// Le compteur vivait dans `dashboard/domain/quote_facts.dart`, où la
/// fraîcheur d'un record l'avait fait naître. Le profil en a eu besoin à son
/// tour — l'avancement d'un programme se compte en jours civils depuis son
/// premier jour — et l'importer depuis le fichier des citations aurait fait
/// dépendre le programme de la maxime du jour. Il vit donc ici, avec les
/// autres utilitaires de date de l'application.
library;

/// Jours civils LOCAUX entre deux instants.
///
/// Par les composantes de date, jamais par une différence d'heures : deux
/// séances à 23 h et 1 h sont à deux heures l'une de l'autre et pourtant à
/// un jour d'écart, et c'est le jour qui compte ici.
///
/// Les deux dates sont reconstruites en UTC. Ce n'est pas un changement de
/// fuseau — les composantes viennent du LOCAL, juste au-dessus — c'est le
/// retrait de l'heure d'été du calcul : dans un fuseau qui avance, la nuit
/// du passage ne dure que 23 heures, et `inDays` rendait alors 0 pour deux
/// jours civils voisins. Un jour par an, « hier » devenait « aujourd'hui ».
int joursCivilsEntre(DateTime debut, DateTime fin) {
  final a = debut.toLocal();
  final b = fin.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
