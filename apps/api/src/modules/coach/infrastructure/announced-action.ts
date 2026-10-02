import { type CoachTurnUsage } from '../domain/coach-model.port';
import { type ChatCompletion } from './chat-completion-stream';
import { addUsage } from './openai-compatible.helpers';

/**
 * L'annonce sans l'action : une recherche, une séance ou un programme
 * promis, et rien derrière.
 *
 * Un petit modèle (Qwen3-4B sur processeur) écrit parfois « Je cherche des
 * exercices pour les pecs. Une minute. » ou « Je vais t'adapter une séance à
 * partir de ton profil. » et rend la main SANS appeler l'outil : la personne
 * attend une suite qui ne viendra jamais (constaté le 1er octobre 2026).
 *
 * Deux étages, parce qu'aucune liste de phrases ne tient seule :
 *
 * 1. [mayAnnounceAction], LARGE et gratuit : la fin du message parle-t-elle
 *    d'une suite (« je vais », « je m'occupe », « un instant »…) ? Il lit les
 *    DEUX dernières phrases : « …je vais te le montrer. C'est là que je
 *    commence. » cache sa promesse sous une dernière phrase anodine.
 * 2. [probeFor], qui tranche : le modèle reçoit l'occasion de faire ce
 *    qu'il a annoncé. Il appelle un outil, et le tour reprend ; il répond
 *    « FIN », et la réponse reste telle quelle. C'est le FAIT (un appel
 *    d'outil) qui décide, pas le texte.
 *
 * Mesuré sur Qwen3-4B (1er octobre 2026), sept promesses réelles contre neuf
 * réponses complètes : le premier étage reconnaît les sept et ne retient
 * aucune des neuf ; le second fait agir le modèle sur les sept. Chacun seul
 * échouait : le second seul faisait fouiller les données après quatre
 * réponses complètes sur neuf, et la formulation prudente ratait trois
 * promesses sur sept. Deux pistes écartées : demander au modèle de JUGER sa
 * réponse (il répondait « non » à sa propre promesse), et offrir l'occasion
 * à toute réponse rendue sans outil (il fouillait ses données après une
 * explication complète et la gâchait).
 */

/** Ce qui, dans une fin de message, parle d'une suite. Large à dessein. */
const SUITE = [
  // « Voici ce que je te propose : » et rien derrière.
  /:\s*$/,
  /\bje vais\b/i,
  /\bon va\b/i,
  /\b(laisse-moi|attends|patiente)\b/i,
  /\b(voyons|regardons|cherchons|vérifions|lançons)\b/i,
  /\b(une minute|un instant|une seconde|un moment|tout de suite|dans la foulée)\b/i,
  /\bje m['’](en )?occupe\b/i,
  /\bje (te |t['’]|vous )?(cherche|regarde|vérifie|consulte|lis|prépare|propose|adapte|construis|crée|compose|calcule|analyse|récupère|planifie|organise|monte|concocte|reviens|lance|montre|envoie|génère|mets en place|ajoute|ajuste|rédige|écris|fais|sors|trouve|programme|note|enregistre)\b/i,
  /\b(arrive|arrivent|suit|suivra|suivent)\b/i,
  // L'élision : « j'ajuste le volume », « j'envoie la séance ».
  /\bj['’](ajoute|ajuste|adapte|analyse|envoie|enregistre|organise|établis|élabore|écris|explique|attends)(?!\p{L})/iu,
];

/**
 * Une séance ou un programme DONNÉ pour fait, n'importe où dans le message.
 * Le client ne le demande qu'en l'absence de proposition : alors, c'est
 * faux (« …j'ai fait une séance de base » après l'avoir écrite en texte,
 * sans la carte qui la rend jouable — constaté).
 */
const CLAIMED = [
  // `(?!\p{L})` et non `\b`, qui ignore les lettres accentuées (« préparé »).
  /\bj['’]ai (fait|préparé|adapté|créé|construit|composé|monté|conçu|élaboré|ajusté|mis en place)(?!\p{L})[^.!?]*\b(séance|programme|plan)s?\b/iu,
  /\bvoici (ta|une|la|ton|un|tes) (séance|programme|plan)s?\b/iu,
];

function claimsUnproposed(text: string): boolean {
  return CLAIMED.some((pattern) => pattern.test(text));
}

/**
 * La fin du message (ses deux dernières phrases) parle-t-elle d'une suite,
 * ou le message donne-t-il pour faite une séance qui n'a pas été proposée ?
 */
export function mayAnnounceAction(text: string): boolean {
  const ending = endingOf(text);
  // Une question à la personne (« Tu veux que je te prépare une séance ? »)
  // lui rend la main : c'est une fin, pas une promesse.
  if (ending === '' || ending.endsWith('?')) return false;
  return SUITE.some((pattern) => pattern.test(ending));
}

/** Les deux dernières phrases : là où se cache une promesse. */
export function endingOf(text: string): string {
  return (
    text
      .trim()
      .split(/(?<=[.!?…:])\s+/)
      // « Tu pourras la suivre pas à pas. ✅ » : un émoji n'est pas une phrase.
      .filter((sentence) => /\p{L}/u.test(sentence))
      .slice(-2)
      .join(' ')
  );
}

/**
 * Une DEMANDE de séance ou de programme, lue dans le message de la personne
 * — plus simple à reconnaître que les mille façons qu'a le modèle de ne pas
 * la faire (« l'adaptation est faite pour t'offrir une séance réaliste »,
 * constaté, sans carte).
 */
const ASKED = [
  /\b(veux|voudrais|aimerais|fais|fais-moi|donne|donne-moi|propose|propose-moi|prépare|prépare-moi|crée|construis|monte|besoin|quelle|quel)\b[^?.!]*\b(séance|programme|entraînement|plan)s?\b/iu,
  /\b(une|ma|la) (séance|programme)\b[^?.!]*\bpour\b/iu,
];

export function asksForPlan(request: string): boolean {
  return ASKED.some((pattern) => pattern.test(request));
}

/**
 * Le message de l'occasion d'agir pour cette réponse, ou `null` s'il n'y a
 * pas lieu. Jamais montré, jamais archivé. Le client ne le demande que si
 * aucune séance ni aucun programme n'a été proposé dans le tour.
 *
 * - Séance DEMANDÉE (et la réponse ne pose pas de question) ou donnée pour
 *   FAITE : un ordre. Le signal est sûr ; mesuré, à la question le modèle
 *   répondait « FIN », à l'ordre il lit les identifiants puis propose, six
 *   fois sur six.
 * - Fin qui parle d'une suite : une question qui CITE cette fin. Mesuré sur
 *   Qwen3-4B, la formulation générale (« si ton message annonce une
 *   action… ») faisait fouiller les données après six réponses complètes sur
 *   neuf ; citée, la fin ne laisse agir que sur ce qui y est promis. « FIN »
 *   vaut réponse complète ; tout autre texte aussi (le client l'interrompt
 *   dès qu'il dépasse « FIN »).
 */
export function probeFor(
  answer: string,
  request: string,
  read: boolean,
): { text: string; keep: boolean } | null {
  // Des données citées sans lecture : la réponse est fausse, sa version
  // corrigée la REMPLACE (`keep: false`).
  if (!read && citesUserData(answer)) return { text: DATA_PROBE, keep: false };
  const asks = !endingOf(answer).endsWith('?') && asksForPlan(request);
  if (asks || claimsUnproposed(answer)) return { text: PROPOSAL_PROBE, keep: true };
  if (!mayAnnounceAction(answer)) return null;
  const text =
    `(Message automatique, pas de l'utilisateur.) Ton message se termine ainsi : « ${endingOf(answer)} ». ` +
    "Si cette fin annonce une action que tu n'as pas faite, fais-la maintenant avec l'outil. " +
    "Sinon — réponse complète, ou question posée à l'utilisateur —, réponds seulement : FIN. " +
    "N'ajoute aucune recherche que tu n'as pas annoncée.";
  return { text, keep: true };
}

/**
 * Ses données citées comme lues (« Tu as déjà des records de soulevé de
 * terre », « j'ai vu tes dernières séances » — constaté, sans aucune
 * lecture) : avoir « vu », ou un chiffre à son sujet. Pas une simple
 * mention (« basée sur ce que tu as déjà soulevé ») : mesuré, celle-ci
 * relançait trois réponses complètes sur neuf. Le client ne le demande que
 * si rien n'a été lu dans le tour.
 */
const CITES_DATA = [
  // Avoir « vu » ses DONNÉES : « J'ai vu tes dernières séances et tes records ».
  // Pas « selon ton objectif » : l'objectif et le niveau lui sont donnés.
  /(?<!\p{L})(j['’]ai (vu|regardé|consulté|vérifié)|d['’]après|selon) (tes|ton|ta) (dernières? )?(séances?|records?|pesées?|données|repas|historique|statistiques|mesures|performances)(?!\p{L})/iu,
  /(?<!\p{L})tu as (déjà )?des records(?!\p{L})/iu,
  // Un CHIFFRE affirmé à son sujet : « Tes records : 120 kg au squat ».
  // Pas « si tu as fait 3 séances » (une condition), ni « augmente ton max ».
  /(?<!\p{L})(?<!si )(tu as (soulevé|fait|réalisé|couru)|tu (pèses|pesais)|(ton|tes) (records?|poids))(?!\p{L})[^.!?\n]{0,60}\d+([,.]\d+)? ?(kg|kilos?|séances?|km|kcal|reps|répétitions)(?!\p{L})/iu,
];

/** Les lectures qui rendent SES données (pas le catalogue d'exercices). */
export const USER_DATA_TOOLS: ReadonlySet<string> = new Set([
  'get_recent_sessions',
  'get_personal_records',
  'get_progress_overview',
  'get_body_weight_trend',
  'get_nutrition_targets',
  'get_recent_meals',
  'get_training_profile',
]);

function citesUserData(answer: string): boolean {
  return CITES_DATA.some((pattern) => pattern.test(answer));
}

const DATA_PROBE =
  "(Message automatique, pas de l'utilisateur.) Ta réponse parle de ses données (séances, " +
  "records, poids, repas) sans les avoir lues : tu ne connais que ce que les outils t'ont " +
  "rendu. Lis maintenant ce dont tu parles avec l'outil adapté, puis réécris ta réponse " +
  'avec les vrais chiffres, sans rien inventer.';

const PROPOSAL_PROBE =
  "(Message automatique, pas de l'utilisateur.) Aucune séance ni aucun programme n'a été " +
  "proposé avec l'outil : l'utilisateur ne peut ni le voir ni le lancer. Propose-le " +
  'maintenant : une séance avec propose_session, après avoir lu les identifiants de ses ' +
  'exercices avec search_exercises ; un programme avec propose_program, après avoir lu ' +
  'get_training_profile.';

/** Au-delà, ce n'est plus « FIN » : le modèle rédige, l'occasion est close. */
const PROBE_TEXT_LIMIT = 4;

/** La requête au modèle du client : charge utile, signal, flux, plafond, worker, essais. */
type Complete = (
  payload: Record<string, unknown>,
  signal: AbortSignal,
  onText: (delta: string) => void,
  maxOutputTokens: number,
  prefer: string | undefined,
  retries: number,
) => Promise<{ completion: ChatCompletion }>;

/**
 * L'occasion d'agir, `messages` finissant par elle : la complétion si le
 * modèle appelle un outil ; `null` s'il répond « FIN », se met à rédiger
 * (coupé net, rien n'est montré) ou si l'essai, unique, échoue — la réponse
 * déjà à l'écran reste la réponse. Seule l'annulation par la personne
 * remonte. Ses jetons comptent, « FIN » compris.
 */
export async function probeForAction(
  complete: Complete,
  messages: Record<string, unknown>[],
  turn: {
    tools: unknown[];
    signal: AbortSignal;
    cancelled: AbortSignal | undefined;
    maxTokens: number;
    worker: string | undefined;
    usage: CoachTurnUsage;
  },
): Promise<ChatCompletion | null> {
  const stop = new AbortController();
  let text = '';
  try {
    const { completion } = await complete(
      { messages, tools: turn.tools },
      AbortSignal.any([turn.signal, stop.signal]),
      (delta) => {
        text += delta;
        if (text.trim().length > PROBE_TEXT_LIMIT) stop.abort();
      },
      turn.maxTokens,
      turn.worker,
      0,
    );
    addUsage(turn.usage, completion);
    return (completion.choices?.[0]?.message?.tool_calls?.length ?? 0) > 0 ? completion : null;
  } catch (error) {
    if (turn.cancelled?.aborted === true) throw error;
    return null;
  }
}
