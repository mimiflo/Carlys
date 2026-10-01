/**
 * L'annonce sans l'action : une recherche, une séance ou un programme
 * promis, et rien derrière.
 *
 * Un petit modèle (Qwen3-4B sur processeur) écrit parfois « Je cherche des
 * exercices pour les pecs. Une minute. » et rend la main SANS appeler
 * l'outil : le tour est fini, la personne attend une suite qui ne viendra
 * jamais (constaté le 1er octobre 2026). Le client le reconnaît à la
 * DERNIÈRE phrase, et relance une fois avec [ANNOUNCED_ACTION_NUDGE].
 *
 * Seule la dernière phrase compte : une réponse complète peut annoncer la
 * suite de l'entraînement (« je vais te laisser essayer »), elle ne se
 * termine pas sur une recherche promise.
 */

/**
 * Dernières phrases qui promettent une recherche, pas une réponse. Étroites
 * à dessein : « Un moment de repos suffit », « D'abord, échauffe-toi » ou
 * « Laisse-moi savoir » terminent de vraies réponses, et chaque fausse
 * alerte coûte un tour de calcul entier.
 */
const PROMISE = [
  /^(une minute|un instant|un moment)\s*[.!…]*$/i,
  /^(vérifions|regardons|cherchons)\b/i,
  /^(d['’]abord,?\s*)?je (cherche|vérifie|consulte)\b/i,
  /^je vais (chercher|regarder|vérifier|consulter|lire|voir|trouver)\b/i,
  /^laisse-moi (chercher|regarder|vérifier|consulter|voir)\b/i,
  // Une séance ou un programme promis, sans la carte qui le propose
  // (« Je vais t’adapter une séance à partir de ton profil. »). L'objet est
  // exigé : « Je te propose de commencer par 3 séries » est une réponse.
  /^(je vais |je |laisse-moi )(te |t['’])?(préparer?|proposer?|adapter?|construire?|construis|créer?|composer?|concocter?|monter?|élaborer?|planifier?)\b.*\b(séance|programme|plan|entraînement)s?\b/i,
];

export function announcesAction(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed === '') return false;
  // « Voici ce que je te propose : » et rien derrière.
  if (trimmed.endsWith(':')) return true;
  const last = trimmed.split(/(?<=[.!?…])\s+/).at(-1) ?? trimmed;
  return PROMISE.some((promise) => promise.test(last));
}

/** La relance, envoyée comme un message de la personne. */
export const ANNOUNCED_ACTION_NUDGE =
  'Tu viens d’annoncer une action sans la faire. Fais-la maintenant : appelle ' +
  'l’outil nécessaire (recherche, proposition de séance ou de programme), puis ' +
  'réponds avec le résultat. Si tu as déjà tout ce qu’il faut, réponds directement.';
