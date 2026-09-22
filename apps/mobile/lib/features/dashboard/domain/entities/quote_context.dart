/// LES DOUZE CONTEXTES d'une maxime.
///
/// Une maxime SANS contexte tourne au calendrier, une par jour : c'est le
/// recueil d'origine, et il reste le repli. Une maxime ÉTIQUETÉE ne sort
/// QUE quand son fait est vrai — et c'est la moitié la plus importante de
/// la règle : « Après une pause, reprends plus léger » s'affichait à tout le
/// monde un jour sur soixante, y compris à qui s'entraîne depuis six mois
/// sans en manquer une.
///
/// Une maxime porte plusieurs étiquettes quand elle sert plusieurs états —
/// « Recommencer fait partie du plan » vaut pour un retour, une pause en
/// cours et une séance abandonnée. Sans ça, il faudrait douze variantes
/// quasi identiques de la même phrase, c'est-à-dire douze listes
/// concurrentes.
library;

enum QuoteContext {
  /// Aucune séance terminée : tout commence.
  premiereSeance,

  /// Une séance AUJOURD'HUI, après un long écart. Le moment le plus fragile
  /// du parcours, et celui qu'on ne rate pas.
  retourApresPause,

  /// Plusieurs jours sans séance, et aucune aujourd'hui. Le miroir du
  /// précédent : dire « content de te revoir » à qui n'est pas revenu serait
  /// aussi faux que l'inverse.
  pauseEnCours,

  /// Une série en cours, assez longue pour compter.
  serieEnCours,

  /// Un record battu tout récemment.
  recordBattu,

  /// Une cible du jour atteinte.
  objectifAtteint,

  /// La dernière séance a été abandonnée en cours.
  seanceAbandonnee,

  /// Le volume de la semaine recule nettement sur la précédente.
  plateau,

  /// Trop de séances dans la semaine. La santé passe avant la félicitation.
  surcharge,

  /// La semaine avance, et rien n'a encore été fait.
  semaineCreuse,

  /// Le repos qui suit une séance, ni trop court ni trop long.
  recuperation,

  /// L'axe Maîtrise attend encore des faits : il y a à apprendre.
  apprentissage,
}
