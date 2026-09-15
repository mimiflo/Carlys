/**
 * Fuseaux horaires IANA : validation à l'écriture, repli sûr à la lecture.
 *
 * POURQUOI CE FICHIER EXISTE. Le fuseau de l'utilisateur (`User.timezone`)
 * sert à découper ses journées d'entraînement côté base
 * (`date_trunc(… AT TIME ZONE …)`). PostgreSQL refuse un fuseau qu'il ne
 * connaît pas : une chaîne quelconque arrivée jusqu'à la colonne
 * transformerait une simple lecture de statistiques en erreur 500.
 *
 * La reconnaissance passe par ICU (`Intl`), qui porte la base IANA : c'est la
 * même table que celle de PostgreSQL, sans liste à maintenir à la main ni
 * expression régulière qui accepterait « Europe/Pariss ».
 */

/** Vrai si `value` est un identifiant de fuseau IANA reconnu (ex. `Europe/Paris`). */
export function isIanaTimeZone(value: unknown): value is string {
  if (typeof value !== 'string' || value.length === 0) {
    return false;
  }
  try {
    // Un fuseau inconnu fait lever un RangeError ; c'est la seule façon
    // portable de poser la question à ICU.
    new Intl.DateTimeFormat('en-US', { timeZone: value });
    return true;
  } catch {
    return false;
  }
}

/**
 * Le fuseau à employer pour une requête, quoi qu'il y ait en base.
 *
 * Une colonne écrite avant que la validation n'existe peut contenir n'importe
 * quoi. On préfère des statistiques découpées en UTC — visiblement décalées,
 * mais lisibles — à une page d'erreur.
 */
export function safeTimeZone(value: unknown): string {
  return isIanaTimeZone(value) ? value : 'UTC';
}
