/**
 * Les SIGNAUX du résolveur d'intention (coach-intent.ts), sur la question
 * sans accents ni majuscules. Chacun est couvert par les formulations de
 * test/fixtures/coach-intents.json, positives comme négatives : une
 * formulation ratée s'y ajoute d'abord, la règle se corrige ensuite.
 */

/** Enregistrer une séance : un verbe d'action ET son objet. */
export const CREATE = [
  // « crée-la », « mets-la pour aujourd'hui », « ajoute-la à mon programme »
  /\b(cree|ajoute|enregistre|sauvegarde|garde|mets|planifie|programme|valide)[sz]?-(la|le|les)\b/,
  // « crée-moi une séance jambes », « ajoute cette séance », « de créer une séance »
  /\b(cree|creer|ajoute|ajouter|enregistre|enregistrer|sauvegarde|sauvegarder|mets|mettre|planifie|planifier)[sz]?(-moi| moi)? (cette|une|la|ma|ce|cet|un) (nouvelle |petite |autre )?(seance|entrainement|workout|routine)\b/,
  // « enregistre ça »
  /\b(cree|ajoute|enregistre|sauvegarde|garde|mets)[sz]? (ca|cela)\b/,
  // « tu peux la créer ? »
  /\b(la|le) (cree[rsz]?|ajoute[rsz]?|enregistre[rsz]?|sauvegarde[rsz]?|garde[rsz]?)\b/,
];

/**
 * Ce qui fait d'un verbe de création autre chose qu'un ordre : une négation
 * (« ne la crée pas »), une demande d'explication (« comment créer une
 * séance ? », « je n'arrive pas à créer… », « est-ce que je dois ajouter… »),
 * une question sur autre chose (« mets-le sur quel cran ? »).
 */
export const NOT_AN_ORDER =
  /\bne\b[^.?!]*\bpas\b|\bn'\w+[^.?!]*\bpas\b|\b(comment|pourquoi|expliqu\w*|est-ce que (je|j'|on|il)|dois-je|je dois|faut-il|il faut|quel|quelle|quels|quelles|combien)\b/;

/** « la », « ça », « cette séance » : la séance déjà en vue. */
export const ANAPHORA =
  /-(la|le)\b|\b(la|le) (cree|ajoute|enregistre|sauvegarde|garde)|\b(ca|cela|cette seance|celle-ci|celle-la)\b/;

/** Changer la séance proposée. */
export const MODIFY =
  /\b(remplace\w*|change\w*|enleve\w*|retire\w*|supprime\w*|ajoute (des|du|de la|un|une)|plus (courte?|longue?|legere?|dure?|intense|facile|simple)|moins (longue?|dure?|de|d')|raccourci\w*|allonge\w*|sans (le|la|les|l')|a la place)\b/;

/** Une question qui reste une demande : « tu peux… ? », « et si… ? ». */
export const POLITE = /\b(tu peux|peux-tu|tu pourrais|pourrais-tu|et si)\b/;

/** Une question de savoir : « comment… », « pourquoi… », « explique-moi… ». */
export const KNOWLEDGE =
  /^\W*(comment|pourquoi|c'est quoi|qu'est-ce qu'?(un|une|la|le|c'est)|quelle (est la )?difference|explique)\b|\b(m'expliquer|explique-moi|expliques-moi)\b/;

/** Ce qu'il faut faire, maintenant : la séance du jour. */
export const WHAT_TO_DO =
  /\b(je fais quoi|je peux faire quoi|que faire|quoi faire|qu'est-ce que je fais|tu me conseilles quoi|que me conseilles[- ]tu|tu me proposes quoi|une idee)\b/;
export const QUICK =
  /\b(quelque chose|un truc) (de )?(rapide|court|simple|efficace|intense)\b|\bun truc\b/;
export const WORK = /\b(travailler|bosser|muscler|renforcer|m'entrainer|entrainer)\b/;
export const WANT = /\b(je veux|j'aimerais|je voudrais|j'ai envie|aujourd'hui|ce soir|ce matin)\b/;
export const SHORT_ON_TIME = /\b(peu de temps|pas (beaucoup|trop|le) (de )?temps|presse)\b/;

/** Ce qui fait d'un « que me conseilles-tu ? » un conseil, pas une séance. */
export const NOT_TRAINING =
  /\b(mange\w*|repas|calories?|kcal|proteines?|glucides|nutrition|boire|hydrat\w*|blessure|blesse|douleur|courbatures?|recup\w*|etirements?|sommeil|dormir)\b/;

export const TRAINING =
  /\b(seances?|entrainements?|exercices?|series?|reps?|repetitions?|repos|echauffement|gainage|muscu\w*|squats?|sport|charges?|programme)\b/;

/** Un REPROCHE (« ça fait 5 fois que je te demande ») — pas « 3 fois par semaine ». */
export const FRUSTRATED =
  /\b(rend fou|marche (pas|jamais|toujours pas)|ca fait \d+ fois|\d+ fois que|(demande|dit|repete)\w* \d+ fois|je te (l'ai |le )?demande|toujours pas|j'en ai marre|ras le bol|enerve)/;

/** Ce qui précise une séance à composer : un format. */
export const DETAILED =
  /\b(full body|corps entier|sans materiel|poids du corps|rapide|courte|express)\b/;

/**
 * Le temps disponible, dans une tournure qui l'annonce (« j'ai 20 min »,
 * « que 30 min », « de 25 minutes ») — pas « 2 min de repos ». En minutes ;
 * `null` s'il n'en dit rien.
 */
export function minutesIn(question: string): number | null {
  const minutes =
    /\b(j'ai|que|seulement|juste|en|de|dispose de|pendant) (\d{1,3}) ?(min|mins|minutes|mn)\b/.exec(
      question,
    )?.[2];
  if (minutes !== undefined) return Number(minutes);
  return /\b(une|1) ?h(eure)?\b/.test(question) ? 60 : null;
}
