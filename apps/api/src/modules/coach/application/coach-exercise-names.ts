/**
 * Les noms d'exercices du coach, ramenés à ceux du catalogue Carlys.
 *
 * Un petit modèle écrit de mémoire « le deadlift » ou « le press de
 * poitrine » (constaté le 1er octobre 2026) là où l'application dit
 * « soulevé de terre » et « développé couché » : la personne cherche ensuite
 * un nom qu'elle ne trouve nulle part. La consigne le demande ; cette
 * réécriture le GARANTIT pour les termes connus, dans le flux comme dans la
 * réponse enregistrée.
 *
 * Le catalogue garde lui-même des noms anglais d'usage (« Hip thrust »,
 * « Pec deck », « Push Press », « Plank jack ») : seuls les termes qui ont un
 * nom français DANS le catalogue sont réécrits, et jamais à l'intérieur d'un
 * nom du catalogue. Les formes dont le genre changerait l'article (« un
 * pull-up » → « une traction ») ne sont réécrites qu'au pluriel, où
 * l'article ne bouge pas.
 */

/** Mots anglais (fragments d'expression régulière) → nom du catalogue. */
const TERMS: readonly (readonly [readonly string[], string])[] = [
  // Noms du catalogue qui CONTIENNENT un terme plus court : laissés tels quels.
  [['plank', 'jacks?'], '$&'],
  [['plank', 'shoulder', 'taps?'], '$&'],
  [['push', 'press'], '$&'],
  [['romanian', 'deadlifts?'], 'soulevé de terre roumain'],
  [['rdl'], 'soulevé de terre roumain'],
  [['sumo', 'deadlifts?'], 'soulevé de terre sumo'],
  [['deadlifts?'], 'soulevé de terre'],
  [['incline', 'bench', 'press'], 'développé incliné'],
  [['bench', 'press'], 'développé couché'],
  [['press', 'de', 'poitrine'], 'développé couché'],
  [['presse', 'de', 'poitrine'], 'développé couché'],
  [['press', 'poitrine'], 'développé couché'],
  [['overhead', 'press'], 'développé militaire'],
  [['military', 'press'], 'développé militaire'],
  [['shoulder', 'press'], 'développé militaire'],
  [['ohp'], 'développé militaire'],
  [['pull-?ups'], 'tractions'],
  [['pull', 'ups'], 'tractions'],
  [['chin-?ups'], 'tractions supinées'],
  [['push-?ups'], 'pompes'],
  [['push', 'ups'], 'pompes'],
  [['walking', 'lunges'], 'fentes marchées'],
  [['lunges'], 'fentes'],
  [['bulgarian', 'split', 'squats'], 'fentes bulgares'],
  [['lat', 'pulldown'], 'tirage vertical'],
  [['bent-?over', 'row'], 'rowing barre buste penché'],
  [['barbell', 'row'], 'rowing barre buste penché'],
  [['calf', 'raises'], 'extensions mollets'],
  [['lateral', 'raises'], 'élévations latérales'],
  [['glute', 'bridges'], 'ponts fessiers'],
  [['glute', 'bridge'], 'pont fessier'],
  [['goblet', 'squats?'], 'squat gobelet'],
  [['hammer', 'curls?'], 'curl marteau'],
  [['skull', 'crushers'], 'barres au front'],
  [['dumbbells'], 'haltères'],
  [['dumbbell'], 'haltère'],
];

const SEPARATOR = '[\\s-]+';
const BOUNDARY_BEFORE = '(?<![\\p{L}\\p{N}-])';
const BOUNDARY_AFTER = '(?![\\p{L}\\p{N}-])';

/**
 * Une alternative NOMMÉE par terme (`t0`, `t1`…), la plus longue d'abord :
 * « bench press » avant « press ». Précédée d'une élision facultative
 * (« l'overhead press » → « le développé militaire », pas « l'développé »).
 */
const ORDERED = [...TERMS].sort((a, b) => b[0].length - a[0].length);
const PATTERN = new RegExp(
  `${BOUNDARY_BEFORE}(?<elision>[ldLD]['’])?(?:${ORDERED.map(
    ([words], index) => `(?<t${index}>${words.join(SEPARATOR)})`,
  ).join('|')})${BOUNDARY_AFTER}`,
  'giu',
);

/** « Deadlift » → « Soulevé de terre » ; « RDL », sigle, ne capitalise rien. */
function capitalized(source: string, replacement: string): string {
  const titlecase = /^\p{Lu}(?!\p{Lu})/u.test(source);
  return titlecase ? replacement.charAt(0).toUpperCase() + replacement.slice(1) : replacement;
}

/** Le texte, ses termes connus remplacés par les noms du catalogue. */
export function frenchExerciseNames(text: string): string {
  return text.replace(PATTERN, (match: string, ...args: unknown[]) => {
    const groups = args.at(-1) as Record<string, string | undefined>;
    const index = ORDERED.findIndex((_, i) => groups[`t${i}`] !== undefined);
    const term = groups[`t${index}`] ?? match;
    const replacement = ORDERED[index]?.[1] ?? '$&';
    if (replacement === '$&') return match;
    const elision = groups.elision;
    const french = capitalized(term, replacement);
    if (elision === undefined) return french;
    // « l' » devant une consonne redevient « le », « d' » « de » ; devant
    // « haltère » (h muet), elle reste.
    return /^[aeiouyhéèêà]/iu.test(french)
      ? `${elision}${french}`
      : `${elision.charAt(0)}e ${french}`;
  });
}

/** Mots d'un terme de plusieurs mots, pour reconnaître son début dans le flux. */
const MULTI_WORD = TERMS.filter(([words]) => words.length > 1).map(([words]) =>
  words.map((word) => new RegExp(`^${word}$`, 'iu')),
);

/** `words` peut-il être le début d'un terme encore incomplet ? */
function startsTerm(tokens: readonly string[]): boolean {
  // « **bench », « (bench », « l'overhead » : la ponctuation ouvrante et
  // l'élision ne font pas partie du terme.
  const words = tokens.map((token, index) =>
    index === 0 ? token.replace(/^[(«"*_[]+/u, '').replace(/^[ldLD]['’]/u, '') : token,
  );
  return MULTI_WORD.some(
    (term) =>
      term.length > words.length && words.every((word, index) => term[index]?.test(word) === true),
  );
}

/**
 * La même réécriture, sur un flux qui arrive par morceaux.
 *
 * Retient le dernier mot (peut-être coupé) et, s'il y en a, le début d'un
 * terme de plusieurs mots (« bench » attend de savoir s'il est suivi de
 * « press ») ; tout le reste part aussitôt. `flush` rend ce qui reste à la
 * fin du tour.
 */
export function frenchExerciseNamesStream(emit: (text: string) => void): {
  push: (delta: string) => void;
  flush: () => void;
} {
  let pending = '';
  const send = (text: string) => {
    if (text !== '') emit(frenchExerciseNames(text));
  };
  return {
    push(delta) {
      pending += delta;
      // Les mots COMPLETS : ceux qu'un espace a déjà refermés — ou tout, sur
      // une ponctuation finale (« …une séance. ») : aucun terme ne la
      // franchit, et la fin d'un tour n'attend pas le suivant.
      const closed = /[.!?…:;)»]$/u.test(pending);
      const lastSpace = Math.max(pending.lastIndexOf(' '), pending.lastIndexOf('\n'));
      if (!closed && lastSpace < 0) return;
      const complete = closed ? pending : pending.slice(0, lastSpace + 1);
      const words = [...complete.matchAll(/\S+/g)];
      let cut = complete.length;
      for (let start = Math.max(0, words.length - 2); start < words.length; start++) {
        const tail = words.slice(start).map((word) => word[0]);
        // Une ponctuation ferme toute expression : rien à attendre.
        if (/[.,;:!?…)»]$/.test(tail.at(-1) ?? '')) break;
        if (startsTerm(tail)) {
          cut = words[start]?.index ?? cut;
          break;
        }
      }
      // Jamais au milieu d'un terme déjà complet : « bench press » reste
      // entier même si « press » pourrait ouvrir « press de poitrine ».
      for (const match of complete.matchAll(PATTERN)) {
        if (match.index < cut && cut < match.index + match[0].length) cut = match.index;
      }
      send(pending.slice(0, cut));
      pending = pending.slice(cut);
    },
    flush() {
      send(pending);
      pending = '';
    },
  };
}
