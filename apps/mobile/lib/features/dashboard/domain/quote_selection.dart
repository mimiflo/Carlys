/// L'ORDRE DE PRIORITÉ DES CONTEXTES — la RÈGLE, pas le recueil.
///
/// Ce fichier dit quels contextes sont vrais aujourd'hui et dans quel ordre
/// ils passent ; il ne connaît aucune phrase. Choisir la maxime qui
/// correspond est le travail de `data/daily_quotes.dart`, où vit le corpus :
/// le domaine ne descend jamais vers les données, et
/// `feature_layers_test.dart` le vérifie.
///
/// LE PRINCIPE QUI ENGENDRE L'ORDRE, et qu'on relit avant d'y toucher :
/// *un moment de bascule bat une célébration ; une célébration bat une
/// fragilité ; une fragilité du jour bat une tendance de la semaine ; une
/// tendance bat un état ordinaire.*
///
/// Deux exceptions, toutes deux motivées par une règle de marque déjà écrite
/// ailleurs :
///
///  - **[QuoteContext.surcharge] passe devant [QuoteContext.serieEnCours]**,
///    alors que les deux sont vrais ensemble dès six jours d'affilée.
///    Féliciter une série de sept jours contredirait la valeur Équilibre —
///    « le repos fait partie de l'entraînement ». La santé passe avant la
///    félicitation ;
///  - **[QuoteContext.retourApresPause] bat [QuoteContext.recordBattu]**.
///    Qui revient après trois semaines est celui qui risque le plus de
///    repartir ; et le record est DÉJÀ dit ailleurs sur le même écran (la
///    carte de titre le remonte, le Mentor le fête dans « Pour toi »). Il
///    n'est pas perdu — il serait dit trois fois.
///
/// SI AUCUN CONTEXTE N'EST VRAI, le repli est la rotation calendaire
/// d'origine, inchangée : même déterminisme, même alternance de valeurs,
/// même phrase sur tous les appareils.
library;

import 'entities/daily_quote.dart';
import 'quote_facts.dart';

/// L'ordre de priorité. Le PREMIER contexte vrai gagne.
const List<QuoteContext> quotePriority = [
  QuoteContext.premiereSeance,
  QuoteContext.retourApresPause,
  QuoteContext.surcharge,
  QuoteContext.recordBattu,
  QuoteContext.objectifAtteint,
  QuoteContext.serieEnCours,
  QuoteContext.seanceAbandonnee,
  QuoteContext.semaineCreuse,
  QuoteContext.pauseEnCours,
  QuoteContext.plateau,
  QuoteContext.recuperation,
  QuoteContext.apprentissage,
];

/// Les contextes VRAIS aujourd'hui, dans l'ordre de priorité.
List<QuoteContext> activeContexts(QuoteFacts facts) =>
    quotePriority.where((contexte) => _estVrai(contexte, facts)).toList();

bool _estVrai(QuoteContext contexte, QuoteFacts facts) {
  return switch (contexte) {
    QuoteContext.premiereSeance => facts.completedSessions == 0,

    // Une séance AUJOURD'HUI, après un long écart. Les deux conditions
    // comptent : sans la première, on dirait « content de te revoir » à qui
    // n'est pas revenu ; sans la seconde, à qui n'est jamais parti.
    QuoteContext.retourApresPause =>
      facts.trainedToday && (facts.gapBeforeLast ?? 0) >= retourApresJours,

    // Le miroir exact : un écart qui dure, et rien aujourd'hui.
    QuoteContext.pauseEnCours =>
      !facts.trainedToday && (facts.daysSinceLast ?? 0) >= pauseApresJours,

    QuoteContext.serieEnCours => facts.streakDays >= serieMinimum,

    QuoteContext.recordBattu => _estFrais(facts.recentRecordAt, facts.today),

    QuoteContext.objectifAtteint => facts.goalReached,

    QuoteContext.seanceAbandonnee => facts.lastSessionAbandoned,

    // Une TENDANCE, jamais un jour : il faut la semaine précédente pour
    // comparer, et au moins un peu de cette semaine pour constater.
    QuoteContext.plateau =>
      facts.lastWeekVolumeKg > 0 &&
          facts.thisWeekVolumeKg > 0 &&
          facts.thisWeekVolumeKg < plateauSeuil * facts.lastWeekVolumeKg,

    QuoteContext.surcharge => facts.trainedThisWeek >= surchargeMinimum,

    QuoteContext.semaineCreuse =>
      facts.trainedThisWeek == 0 &&
          facts.today.toLocal().weekday >= semaineCreuseDepuis,

    QuoteContext.recuperation => _enRecuperation(facts),

    QuoteContext.apprentissage => facts.masteryPending,
  };
}

/// Un record est-il assez frais pour qu'on le fête ?
///
/// TROIS défauts vivaient sur l'ancienne ligne, et ils se compensaient assez
/// souvent pour passer inaperçus.
///
/// Elle comptait `today.difference(record).inDays`, c'est-à-dire des
/// tranches de 24 heures écoulées, là où `recordFraisJours` parle de JOURS
/// CIVILS. Un record battu hier à 23 h était donc « d'aujourd'hui » à 20 h
/// ce soir — 21 heures, zéro tranche.
///
/// Et elle bornait à `<= recordFraisJours`, soit trois valeurs pour une
/// constante qui en promet deux : son commentaire dit « ce jour-là et le
/// suivant », `docs/product/citations.md` disait « aujourd'hui ou hier ».
/// Cumulé au premier défaut, un record pouvait être fêté jusqu'à près de
/// quatre jours après, bien après que la personne l'ait oublié.
///
/// Le garde-fou `jours >= 0`, enfin, ne gardait rien : une date au FUTUR de
/// moins de 24 heures rendait `inDays == 0`, donc « aujourd'hui ». Une
/// horloge d'appareil en avance suffisait à faire féliciter un record qui
/// n'existait pas encore. En jours civils, demain est demain.
bool _estFrais(DateTime? record, DateTime today) {
  if (record == null) {
    return false;
  }
  final jours = joursCivilsEntre(record, today);
  return jours >= 0 && jours < recordFraisJours;
}

bool _enRecuperation(QuoteFacts facts) {
  final heures = facts.hoursSinceLast;
  return !facts.trainedToday &&
      heures != null &&
      heures >= recuperationMinHeures &&
      heures < recuperationMaxHeures;
}
