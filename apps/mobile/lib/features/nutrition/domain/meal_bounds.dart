/// Les bornes d'un REPAS, recopiées du contrat serveur
/// (`apps/api/src/modules/nutrition/domain/meal-bounds.ts` et
/// `packages/api-contracts/src/nutrition.ts`) en un seul endroit.
///
/// L'écran les applique à la saisie, pour ne pas découvrir un 400 à l'envoi.
/// Une borne recopiée dans deux fichiers est une borne qu'on oublie de
/// corriger dans l'un des deux : tout le mobile lit celles-ci.
abstract final class MealBounds {
  /// Calories d'un repas saisi à la main.
  static const int kcalMin = 1;
  static const int kcalMax = 10000;

  /// Chaque macro : de 0 (« aucune ») à 1 000 g.
  static const int macroMaxG = 1000;

  /// La quantité descriptive, bornée par la colonne (`Decimal(7, 2)`).
  static const double quantityMin = 0.01;
  static const double quantityMax = 9999.99;

  /// Une ligne d'une composition : 1 à 5 000 g, deux décimales.
  static const double componentMinG = 1;
  static const double componentMaxG = 5000;

  /// Trente aliments au plus par repas.
  static const int componentsMax = 30;

  /// Le nom, de 1 à 120 caractères.
  static const int nameMaxLength = 120;

  /// La photo du plat : 5 Mio au plus (`MEAL_PHOTO_MAX_BYTES`), coupés par
  /// le serveur PENDANT la réception.
  static const int photoMaxBytes = 5 * 1024 * 1024;

  /// Le plus grand côté d'une photo envoyée : de quoi reconnaître un plat
  /// sur n'importe quel écran de téléphone, pour quelques centaines de Ko.
  static const int photoMaxSide = 1600;

  /// La qualité JPEG de l'envoi : au-delà, le poids croît sans que l'œil
  /// voie la différence sur une vignette ou un plein écran.
  static const int photoQuality = 80;

  /// Une recherche d'aliment : deux caractères au moins (une lettre seule
  /// rendrait la moitié de la table), vingt résultats par réponse.
  static const int foodSearchMinLength = 2;
  static const int foodSearchLimit = 20;

  /// La quantité proposée pour un aliment qu'on vient de choisir : les
  /// valeurs de la table sont données pour 100 g.
  static const double componentDefaultG = 100;
}
