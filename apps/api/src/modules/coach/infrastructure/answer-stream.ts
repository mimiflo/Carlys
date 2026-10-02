/**
 * Le texte d'une réponse et de ses reprises, au fil du flux : le mot coupé
 * jamais montré, la reprise raccordée sans doublon (answer-continuation.ts).
 */

/**
 * La consigne interne d'une reprise : jamais montrée, jamais archivée.
 *
 * Mesuré sur Qwen3-4B (2 octobre 2026, 9 réponses coupées pour de vrai,
 * trois consignes) : laisser la réponse partielle en dernier message ne la
 * fait PAS continuer, il recommence ; « continue à partir du dernier
 * caractère » réécrit ou saute la fin de phrase 3 fois sur 9 ; CITER ses
 * derniers mots la fait repartir au mot près 8 fois sur 9. Le raccord
 * ([stitch]) rattrape le reste.
 */
export function continuationPrompt(base: string): string {
  const words = base.trim().split(/\s+/);
  return (
    "(Message automatique, pas de l'utilisateur.) Ta réponse a été coupée net après ces " +
    `mots : « …${words.slice(-8).join(' ')} ». Écris UNIQUEMENT ce qui vient après, en ` +
    `commençant par le mot qui suit « ${words.at(-1) ?? ''} » — sans recopier ni résumer le ` +
    'début. Si elle était terminée, réponds seulement : FIN'
  );
}

/** « FIN » (et rien d'autre) : la réponse était complète. */
export function saysFin(continuation: string): boolean {
  return /^\s*fin\s*[.!]?\s*$/i.test(continuation);
}

const OVERLAP_MAX_WORDS = 12;

/**
 * La réponse partielle, sans son dernier mot s'il est peut-être coupé
 * (« …en fonction de l'é »). La continuation repart d'une frontière de mot
 * et réécrit ce mot en entier : décider sinon si « volution » finit « l'é »
 * ou si « et des fentes » suit « squats » demanderait un dictionnaire. Ce
 * mot n'a jamais été montré : le flux retient toujours le dernier mot
 * jusqu'à l'espace suivante.
 */
export function atWordBoundary(text: string): string {
  return text.replace(/[\p{L}\p{N}'’-]+$/u, '');
}

/**
 * Raccorde une reprise à la réponse partielle, sans doublon à la jointure —
 * et seulement là. Mesuré sur Qwen3-4B (2 octobre 2026), la reprise :
 *
 * - répète souvent les derniers mots (« …au développé incliné » puis
 *   « développé incliné avec 3 séries ») : ce recouvrement est retiré ;
 * - réécrit parfois la fin de phrase (« …la charge, le nombre de » puis
 *   « en augmentant le nombre de répétitions ») : la suite repart après les
 *   derniers mots retrouvés (trois au moins, dans ses douze premiers) ;
 * - RECOMMENCE parfois la réponse entière : elle n'est gardée qu'à partir
 *   des quatre derniers mots, retrouvés ; sinon, `null` — rien à raccorder.
 *
 * Mots comparés sans casse ni ponctuation. Le résultat commence toujours
 * par `previous` : ce qui est montré n'est jamais réécrit.
 */
export function stitch(previous: string, continuation: string): string | null {
  const next = continuation.replace(/^\s+/, '');
  if (next === '' || previous.trim() === '') return previous + next;
  const drop = restarts(previous, next) ? anchorEnd(previous, next) : overlapEnd(previous, next);
  if (drop === null) return null;
  return join(previous, dropWords(next, drop));
}

function join(previous: string, rest: string): string {
  if (rest.trim() === '') return previous;
  // Une ponctuation dite deux fois (« rythme : » puis « : elle… »), ou qui
  // ouvre la suite d'une phrase finie (« …de santé. » puis « : si tu… »).
  const end = previous.trimEnd().at(-1) ?? '';
  const opening = rest.trimStart().at(0) ?? '';
  const tidy =
    /[.,;:!?…]/.test(end) && (opening === end || /[,;:]/.test(opening))
      ? rest.trimStart().slice(1)
      : rest;
  if (/\s$/.test(previous)) return previous + tidy.replace(/^[ \t]+/, '');
  if (/^\s/.test(tidy) || /^[.,;:!?…)»\]]/.test(tidy)) return previous + tidy;
  return `${previous} ${tidy}`;
}

/** La reprise recommence-t-elle la réponse ? Ses quatre premiers mots sont ceux du début. */
function restarts(previous: string, next: string): boolean {
  const opening = words(previous);
  return opening.length >= 8 && sameWords(words(next).slice(0, 4), opening.slice(0, 4));
}

/** Mots de la reprise à retirer : le recouvrement à la jointure, ou un peu plus loin. */
function overlapEnd(previous: string, next: string): number {
  const tail = words(previous).slice(-OVERLAP_MAX_WORDS);
  const head = words(next).slice(0, OVERLAP_MAX_WORDS);
  for (let size = Math.min(tail.length, head.length); size >= 1; size--) {
    if (sameWords(tail.slice(-size), head.slice(0, size))) return size;
  }
  return findTail(tail, head, 3) ?? 0;
}

/** Une reprise qui recommence : gardée après les quatre derniers mots, sinon `null`. */
function anchorEnd(previous: string, next: string): number | null {
  return findTail(words(previous).slice(-OVERLAP_MAX_WORDS), words(next), 4);
}

/** Fin, dans `head`, de la plus longue fin de `tail` (au moins `min` mots). */
function findTail(tail: string[], head: string[], min: number): number | null {
  for (let size = tail.length; size >= min; size--) {
    const needle = tail.slice(-size);
    for (let at = 0; at + size <= head.length; at++) {
      if (sameWords(head.slice(at, at + size), needle)) return at + size;
    }
  }
  return null;
}

function sameWords(a: string[], b: string[]): boolean {
  return a.length === b.length && a.every((word, index) => word === b[index]);
}

/** `text` sans ses `count` premiers mots — mise en forme du reste intacte. */
function dropWords(text: string, count: number): string {
  if (count === 0) return text;
  let seen = 0;
  for (const match of text.matchAll(/\S+/g)) {
    if (normalized(match[0]) !== '') seen++;
    if (seen === count) return text.slice(match.index + match[0].length);
  }
  return '';
}

function normalized(word: string): string {
  return word.toLowerCase().replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, '');
}

function words(text: string): string[] {
  return text
    .split(/\s+/)
    .map(normalized)
    .filter((word) => word !== '');
}

/**
 * La reprise raccordée, dès qu'on peut trancher ; `undefined` : pas encore.
 * Une reprise qui recommence attend ses derniers mots retrouvés ; une autre,
 * assez de mots pour trancher entre « FIN » et un recouvrement.
 */
function decide(base: string, pending: string): string | undefined {
  const next = pending.replace(/^\s+/, '');
  if (restarts(base, next)) {
    // Jamais raccordée sur un mot encore en cours d'écriture (« de » de « deux »).
    const written = /\s$/.test(next) ? next : atWordBoundary(next);
    if (anchorEnd(base, written) === null) return undefined;
    const joined = stitch(base, written);
    return joined === null ? undefined : joined + next.slice(written.length);
  }
  if (words(next).length <= OVERLAP_MAX_WORDS) return undefined;
  return stitch(base, next) ?? undefined;
}

/**
 * Le texte d'UN appel au modèle et de ses reprises, au fil du flux.
 *
 * Le dernier mot est retenu jusqu'au caractère qui le termine : coupé, il
 * n'a donc jamais été montré, et la reprise le réécrit en entier. Le début
 * d'une reprise est retenu le temps de savoir s'il dit « FIN » ou répète
 * les derniers mots ; au-delà, il passe tel quel. Ce qui est montré ne se
 * reprend jamais : chaque morceau émis prolonge le précédent.
 */
export class AnswerStream {
  text = '';
  private shown = 0;
  private base = '';
  private before = '';
  private pending: string | null = null;

  constructor(private readonly emit?: (delta: string) => void) {}

  readonly push = (delta: string): void => {
    if (this.pending === null) {
      this.text += delta;
    } else {
      this.pending += delta;
      const decided = decide(this.base, this.pending);
      if (decided === undefined) return;
      this.text = decided;
      this.pending = null;
    }
    this.show(withoutFin(atWordBoundary(this.text)));
  };

  /**
   * Avant une reprise : la suite repartira de ce texte — sans son dernier
   * mot s'il est peut-être coupé (`cut` : plafond, panne). Après un `stop`,
   * le modèle a fini son mot : il reste.
   */
  resume(cut: boolean): string {
    this.before = this.text;
    this.base = cut ? atWordBoundary(this.text) : this.text;
    this.pending = '';
    return this.base;
  }

  /**
   * Après une reprise : `fin` si elle dit la réponse finie (« FIN ») ;
   * `rejected` si elle n'apporte rien — vide (appel tombé avant son premier
   * mot) ou recommencée sans rejoindre la réponse.
   */
  settle(): 'added' | 'fin' | 'rejected' {
    const pending = this.pending;
    this.pending = null;
    if (pending === null) return 'added';
    if (saysFin(pending)) {
      this.text = this.before;
      return 'fin';
    }
    const stitched = pending.trim() === '' ? null : stitch(this.base, pending);
    if (stitched === null) {
      this.text = this.before;
      return 'rejected';
    }
    this.text = stitched;
    return 'added';
  }

  /**
   * La réponse laissée incomplète, « … » à la suite : coupée net au dernier
   * mot entier (`cut`), ou telle quelle si le modèle l'a arrêtée lui-même.
   */
  truncate(cut: boolean): void {
    const kept = cut ? atWordBoundary(this.text) : this.text;
    // Jamais en deçà de ce qui est déjà montré, espace finale comprise.
    this.text = `${kept.trimEnd().length >= this.shown ? kept.trimEnd() : kept}…`;
  }

  /**
   * Montre ce qui restait retenu — sans un « FIN » final : le mot de la
   * consigne interne, que le modèle ajoute parfois à une vraie réponse
   * (« …ton corps. FIN. », constaté au banc). Retenu dans le flux tant que
   * rien ne le suit, il n'a jamais été montré.
   */
  flush(): void {
    const kept = withoutFin(this.text);
    if (kept.length >= this.shown) {
      // L'espace d'avant « FIN » peut être déjà montrée : elle reste.
      this.text = kept.trimEnd().length >= this.shown ? kept.trimEnd() : kept;
    }
    this.show(this.text);
  }

  private show(upTo: string): void {
    if (upTo.length <= this.shown) return;
    this.emit?.(upTo.slice(this.shown));
    this.shown = upTo.length;
  }
}

/** `text` sans un « FIN » final, ponctuation comprise (« … FIN. »). */
function withoutFin(text: string): string {
  return text.replace(/(^|[\s.!?…])FIN[.!]?\s*$/u, '$1');
}
