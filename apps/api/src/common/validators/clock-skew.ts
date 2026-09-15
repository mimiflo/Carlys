/**
 * La borne haute des dates fournies par un APPAREIL.
 *
 * POURQUOI UNE TOLÉRANCE, ET PAS `new Date()`. Les dates d'événement —
 * début de séance, date de pesée — sont posées par l'horloge du téléphone,
 * jamais corrigées par le serveur : `DateTime.now().toUtc()` côté mobile. Une
 * horloge en avance de quelques minutes est banale. Refuser à la seconde près
 * ferait rejeter une séance PARFAITEMENT légitime — et le refus ne serait pas
 * anodin : la file de synchronisation traite un 4xx comme DÉFINITIF, jamais
 * rejoué, donc la séance serait perdue. Perdre le travail de quelqu'un pour
 * corriger une statistique est un mauvais échange.
 *
 * Un jour, donc : assez large pour qu'aucune dérive d'horloge réelle ne
 * bloque un envoi, assez étroit pour arrêter ce que cette borne vise
 * vraiment — une date aberrante (année 2099, mois prochain) qui, faute de
 * borne haute dans les requêtes de statistiques, se comptait dans TOUTES les
 * périodes et pour toujours.
 *
 * Cette borne est la seconde ligne de défense, pas la première : les requêtes
 * de statistiques ferment désormais leur fenêtre des DEUX côtés (voir
 * `progress.repository.ts`). Une date d'un jour en avance y est donc sans
 * effet, ce qui est bien le but — laisser passer le bénin, arrêter l'absurde.
 */
const CLOCK_SKEW_TOLERANCE_MS = 24 * 60 * 60 * 1_000;

/** À passer à `@MaxDate(...)` : évalué à CHAQUE validation, jamais figé. */
export function nowWithClockSkew(): Date {
  return new Date(Date.now() + CLOCK_SKEW_TOLERANCE_MS);
}
