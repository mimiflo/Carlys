/// DÉPLACER UNE CASE du calendrier — la règle, sans réseau ni horloge.
///
/// La feuille d'une case disait déjà, à qui n'avait pas la bonne séance ce
/// jour-là : « une séance faite un AUTRE jour ne coche pas cette case :
/// c'est la case qu'il faut déplacer. » Le geste, lui, n'existait pas. Une
/// phrase qui désigne une action absente est pire qu'un silence : elle fait
/// chercher.
///
/// Ce fichier ne tient que l'arithmétique du déplacement, pour qu'elle
/// s'éprouve cas par cas. L'écriture — relire le programme frais, enregistrer
/// le remplacement — reste au contrôleur, comme pour [ProgramActions.setDay].
library;

import 'entities/program.dart';
import 'entities/program_calendar.dart';

/// Déplace la case du jour [fromDayOfWeek] vers [toDayOfWeek], dans la MÊME
/// semaine.
///
/// **Le déplacement se fait dans la semaine, et pas au-delà.** Le calendrier
/// montre une semaine à la fois : déplacer hors de ce cadre serait déplacer
/// vers quelque chose qu'on ne voit pas. Changer de semaine reste une
/// modification du programme, qui a sa propre porte.
///
/// **Si le jour d'arrivée porte déjà une case, les deux ÉCHANGENT.** C'est la
/// seule issue qui ne perd rien : écraser ferait disparaître une séance
/// prévue sans le dire, et refuser obligerait à vider le jour d'arrivée
/// d'abord — deux gestes pour intervertir un mardi et un jeudi, ce que
/// personne ne fait. Une exception : une case déjà FAITE ne bouge pas, ni au
/// départ ni à l'arrivée ([daysHeldBySession]). Cette fonction ne la voit
/// pas (un programme ne sait pas ce qui a été fait) : c'est à l'appelant de
/// la tenir, avec le calendrier.
///
/// **Les identifiants suivent leur case, pas leur jour.** Une case garde son
/// `id` en changeant de jour : c'est elle qu'on déplace, et le serveur la
/// reconnaît. Une case NEUVE serait un autre objet, et le lien qu'une séance
/// a pu nouer avec elle tomberait.
///
/// Rend le programme INCHANGÉ quand le déplacement n'a pas de sens : même
/// jour de départ et d'arrivée, jour hors de 1–7, ou aucune case au départ.
/// Un appelant n'a donc pas à se garder lui-même ; il peut comparer
/// l'identité du résultat pour savoir si quelque chose a bougé.
ProgramDetail moveProgramDay(
  ProgramDetail program, {
  required int weekNumber,
  required int fromDayOfWeek,
  required int toDayOfWeek,
}) {
  if (fromDayOfWeek == toDayOfWeek ||
      !_estUnJour(fromDayOfWeek) ||
      !_estUnJour(toDayOfWeek)) {
    return program;
  }

  final depart = program.dayAt(weekNumber, fromDayOfWeek);
  if (depart == null) {
    return program;
  }
  final arrivee = program.dayAt(weekNumber, toDayOfWeek);

  final autres = [
    for (final jour in program.days)
      if (jour.id != depart.id && jour.id != arrivee?.id) jour,
  ];

  return program.copyWith(
    days: [
      ...autres,
      _auJour(depart, toDayOfWeek),
      if (arrivee != null) _auJour(arrivee, fromDayOfWeek),
    ],
  );
}

/// Les jours de la semaine dont la case est HONORÉE par une séance : une
/// case ne s'y déplace pas, et elle n'en part pas.
///
/// Le serveur déduit « fait » de l'IDENTIFIANT de la case, pas de sa date.
/// Échanger une case à faire avec une case faite emportait donc la séance
/// vers l'autre jour : le calendrier disait qu'on s'était entraîné jeudi
/// quand la séance avait eu lieu mercredi, et le mercredi passait
/// « manqué ». Le serveur refuse désormais ce déplacement en 409 ; la
/// feuille ne le propose plus, et le contrôleur le refuse avant d'écrire.
Set<int> daysHeldBySession(ProgramCalendarWeek week) => {
  for (final day in week.days)
    if (day.sessionId != null || day.status == ProgramDayStatus.done)
      day.dayOfWeek,
};

/// La phrase du refus, écrite pour la personne : un jour déjà fait ne change
/// pas de date.
const heldDayMoveRefusal =
    'Une séance déjà faite tient ce jour-là : sa case ne change pas de '
    'date. Choisis un jour encore à faire.';

/// Lundi (1) à dimanche (7), la convention de l'API.
bool _estUnJour(int dayOfWeek) => dayOfWeek >= 1 && dayOfWeek <= 7;

/// La même case, un autre jour. Tout le reste est conservé — y compris l'id,
/// qui est ce qui fait d'elle la MÊME case aux yeux du serveur.
ProgramDayEntry _auJour(ProgramDayEntry jour, int dayOfWeek) => ProgramDayEntry(
  id: jour.id,
  weekNumber: jour.weekNumber,
  dayOfWeek: dayOfWeek,
  label: jour.label,
  isRest: jour.isRest,
  templateId: jour.templateId,
);
