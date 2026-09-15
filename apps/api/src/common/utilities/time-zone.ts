/**
 * Fuseaux horaires IANA : validation à l'écriture, repli sûr à la lecture.
 *
 * POURQUOI CE FICHIER EXISTE. Le fuseau de l'utilisateur (`User.timezone`)
 * sert à découper ses journées d'entraînement côté base
 * (`date_trunc(… AT TIME ZONE …)`). PostgreSQL refuse un fuseau qu'il ne
 * connaît pas : une chaîne quelconque arrivée jusqu'à la colonne
 * transformerait une simple lecture de statistiques en erreur 500.
 *
 * POURQUOI « ICU L'ACCEPTE » NE SUFFIT PAS. Le contrôle s'est longtemps
 * résumé à « `new Intl.DateTimeFormat(…, { timeZone: value })` ne lève pas ».
 * Depuis ICU 72, `Intl` accepte aussi les DÉCALAGES BRUTS — mesuré sur Node
 * 22, la version du dépôt : `+05:30`, `+0530`, `-08:00` et `+05` passent tous.
 * Ce ne sont pas des identifiants IANA, et le message du décorateur promet
 * pourtant « identifiant IANA attendu, ex. Europe/Paris ». N'importe quel
 * client pouvait donc écrire `{"timezone":"+05:30"}` : la valeur atteignait la
 * colonne, `safeTimeZone` la réacceptait, et elle partait telle quelle dans
 * `AT TIME ZONE` — exactement le cas que la garde existait pour rendre
 * impossible.
 *
 * CE QUI TRANCHE MAINTENANT. ICU sert à CANONISER (`resolvedOptions()
 * .timeZone`), pas à valider : le nom canonique doit ensuite figurer dans la
 * liste des fuseaux qu'ICU déclare supporter. Cet ordre est ce qui permet
 * d'accepter les ALIAS que les téléphones renvoient vraiment — `US/Pacific`
 * devient `America/Los_Angeles`, `Asia/Kolkata` devient `Asia/Calcutta` —
 * tout en refusant les décalages, qui se canonisent en eux-mêmes et ne sont
 * dans aucune liste.
 */

/**
 * Les fuseaux qu'ICU déclare supporter, sous leur nom CANONIQUE.
 *
 * Calculée une fois : la liste ne change pas en cours d'exécution, et elle
 * compte quelques centaines d'entrées (418 sur Node 22 — le nombre suit la
 * version d'ICU, il n'est donc pas écrit en dur ailleurs).
 */
const ZONES_CANONIQUES: ReadonlySet<string> = new Set(Intl.supportedValuesOf('timeZone'));

/**
 * `UTC` n'est PAS dans `supportedValuesOf('timeZone')` — mesuré. C'est
 * pourtant un identifiant IANA parfaitement valide, que PostgreSQL connaît, et
 * surtout la valeur sur laquelle [safeTimeZone] se replie : sans cette
 * exception, le repli lui-même serait jugé invalide.
 */
const UTC = 'UTC';

/**
 * Le préfixe `Etc/` regroupe les fuseaux à décalage FIXE de la base IANA
 * (`Etc/GMT+5`, `Etc/UTC`…). Ce sont de vrais identifiants, connus de
 * PostgreSQL, mais absents de la liste canonique d'ICU. Les accepter par leur
 * NOM ne rouvre pas la porte aux décalages bruts : `+05:30` n'est pas un nom.
 */
const PREFIXE_DECALAGES_NOMMES = 'Etc/';

/**
 * Le nom canonique d'un fuseau selon ICU, ou `null` si ICU ne le connaît pas.
 *
 * Un fuseau inconnu fait lever un `RangeError` ; c'est la seule façon portable
 * de poser la question.
 */
function nomCanonique(value: string): string | null {
  try {
    return new Intl.DateTimeFormat('en-US', { timeZone: value }).resolvedOptions().timeZone;
  } catch {
    return null;
  }
}

/** Vrai si `value` est un identifiant de fuseau IANA reconnu (ex. `Europe/Paris`). */
export function isIanaTimeZone(value: unknown): value is string {
  if (typeof value !== 'string' || value.length === 0) {
    return false;
  }
  const canonique = nomCanonique(value);
  if (canonique === null) {
    return false;
  }
  return (
    ZONES_CANONIQUES.has(canonique) ||
    canonique === UTC ||
    canonique.startsWith(PREFIXE_DECALAGES_NOMMES)
  );
}

/**
 * Le fuseau à employer pour une requête, quoi qu'il y ait en base.
 *
 * Une colonne écrite avant que la validation n'existe peut contenir n'importe
 * quoi — y compris un `+05:30` que l'ancienne version de [isIanaTimeZone]
 * laissait passer. On préfère des statistiques découpées en UTC —
 * visiblement décalées, mais lisibles — à une page d'erreur.
 */
export function safeTimeZone(value: unknown): string {
  return isIanaTimeZone(value) ? value : UTC;
}
