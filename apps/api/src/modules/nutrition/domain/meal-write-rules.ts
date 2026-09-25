/**
 * Qui fait foi, du client ou du calcul ? Les règles d'écriture d'un repas.
 *
 * Un repas est SAISI À LA MAIN (ses totaux sont ce que la personne a tapé)
 * ou COMPOSÉ (ses totaux se calculent depuis ses aliments). Jamais les deux
 * à la fois : si le client pouvait envoyer des aliments ET des calories,
 * l'un des deux serait ignoré en silence, et personne ne saurait lequel.
 * D'où un 400 explicite plutôt qu'une priorité implicite.
 *
 * Fonctions pures : elles rendent le message à opposer, ou `null` si
 * l'écriture est cohérente ; le service décide du statut HTTP.
 */

/** Les champs que la composition CALCULE, et qu'un repas composé ne reçoit pas. */
export const COMPUTED_FIELDS = [
  'kcal',
  'proteinG',
  'carbsG',
  'fatG',
  'quantity',
  'quantityUnit',
] as const;
export type ComputedField = (typeof COMPUTED_FIELDS)[number];

/**
 * Une ligne demandée par le client. `id` vient de l'appareil : dans une
 * correction, un `id` déjà présent dans le repas désigne une ligne à GARDER
 * (son instantané), un `id` neuf une ligne à lire dans la base.
 */
export interface ComponentRequest {
  readonly id: string;
  readonly foodCode: number;
  readonly quantityG: number;
}

/**
 * Ce qu'un corps demande à la composition :
 *  - `keep`    : champ absent, la composition existante ne bouge pas ;
 *  - `clear`   : liste vide, le repas redevient saisi à la main ;
 *  - `replace` : liste non vide, elle remplace toute la composition.
 */
export type CompositionChange =
  | { readonly kind: 'keep' }
  | { readonly kind: 'clear' }
  | { readonly kind: 'replace'; readonly items: readonly ComponentRequest[] };

export function compositionChange(
  components: readonly ComponentRequest[] | undefined,
): CompositionChange {
  if (components === undefined) {
    return { kind: 'keep' };
  }
  return components.length === 0 ? { kind: 'clear' } : { kind: 'replace', items: components };
}

/**
 * Les champs calculés que le corps PORTE — `null` compris : envoyer
 * `proteinG: null` avec des aliments, c'est encore prétendre dire la macro.
 */
export function computedFieldsSent(body: Partial<Record<ComputedField, unknown>>): ComputedField[] {
  return COMPUTED_FIELDS.filter((field) => body[field] !== undefined);
}

/** Les valeurs calculées telles qu'un repas les porte (quantité en nombre). */
export type ComputedValues = Readonly<Record<ComputedField, number | string | null>>;

/**
 * Les champs calculés que le corps CHANGE : envoyés ET différents de la
 * valeur stockée.
 *
 * Renvoyer à l'identique ce qu'on a lu n'est pas une correction. C'est ce
 * que fait l'écran de correction déjà publié, qui envoie toutes ses clés à
 * chaque enregistrement : sans cette règle, renommer un repas composé
 * depuis cette version-là échouait en 400, alors que rien de calculé ne
 * bougeait.
 */
export function computedFieldsChanged(
  body: Partial<Record<ComputedField, unknown>>,
  stored: ComputedValues,
): ComputedField[] {
  return computedFieldsSent(body).filter((field) => body[field] !== stored[field]);
}

function listed(fields: readonly ComputedField[]): string {
  return fields.join(', ');
}

/** Aliments ET totaux dans le même corps : lequel ferait foi ? */
function ambiguity(fields: readonly ComputedField[]): string {
  return (
    'Avec des aliments, le serveur calcule lui-même les calories, les macros et la ' +
    `quantité : n’envoie pas ${listed(fields)} avec « components ».`
  );
}

/** Ce qu'une création va écrire, ou pourquoi elle est refusée. */
export type CreationPlan =
  | { readonly kind: 'refused'; readonly message: string }
  | { readonly kind: 'manual'; readonly kcal: number }
  | { readonly kind: 'composed'; readonly items: readonly ComponentRequest[] };

/**
 * Règle d'une création : saisie à la main (calories obligatoires) ou
 * composée (aucun champ calculé). Une liste vide vaut « pas de
 * composition » : le repas est alors manuel.
 */
export function creationPlan(
  body: Partial<Record<ComputedField, unknown>> & {
    readonly kcal?: number;
    readonly components?: readonly ComponentRequest[];
  },
): CreationPlan {
  const change = compositionChange(body.components);
  const sent = computedFieldsSent(body);
  if (change.kind === 'replace') {
    return sent.length > 0
      ? { kind: 'refused', message: ambiguity(sent) }
      : { kind: 'composed', items: change.items };
  }
  return body.kcal === undefined
    ? {
        kind: 'refused',
        message: 'Donne les calories du repas, ou compose-le à partir d’aliments.',
      }
    : { kind: 'manual', kcal: body.kcal };
}

/**
 * Règle d'une correction.
 *
 * Corriger à la main les totaux d'un repas COMPOSÉ sans toucher à sa
 * composition est refusé : le total ne correspondrait plus aux aliments
 * affichés juste en dessous. Retirer la composition (`components: []`)
 * rend le repas à la saisie manuelle, en GARDANT ses derniers totaux ; ce
 * même corps peut alors les corriger.
 *
 * `sent` : pour une composition gardée, les champs qui CHANGENT
 * (`computedFieldsChanged`) ; pour une composition remplacée, tous ceux
 * qui sont envoyés (`computedFieldsSent`), puisque rien ne dit à quoi les
 * comparer.
 */
export function patchConflict(
  change: CompositionChange,
  sent: readonly ComputedField[],
  storedIsComposed: boolean,
): string | null {
  if (change.kind === 'replace' && sent.length > 0) {
    return ambiguity(sent);
  }
  if (change.kind === 'keep' && storedIsComposed && sent.length > 0) {
    return (
      'Ce repas est calculé à partir de ses aliments : pour corriger ' +
      `${listed(sent)} à la main, retire d’abord sa composition (« components » vide).`
    );
  }
  return null;
}
