import {
  COMMUNITY_REPORT_DETAILS_MAX_LENGTH,
  createCommunityReportSchema,
  createFriendChallengeRequestSchema,
  ENCOURAGEMENT_MESSAGE_MAX_LENGTH,
  encourageRequestSchema,
  FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH,
  FRIEND_CHALLENGE_TITLE_MAX_LENGTH,
} from '@carlys/api-contracts';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { type ZodType } from 'zod';
import { CreateFriendChallengeDto, EncourageDto } from './community.dto';
import { CreateCommunityReportDto } from './community-moderation.dto';

/**
 * CE QUE CE FICHIER PROTÈGE : l'API et le contrat qu'elle publie disent la
 * MÊME chose de la longueur de chaque texte libre de la communauté.
 *
 * Ils ne le disaient pas. `@MaxLength` (validator.js) compte une paire de
 * substitution pour un et efface les sélecteurs de variante ; le contrat
 * (`z.string().max()`) comptait les unités UTF-16. Même constante, deux
 * règles : l'API acceptait 280 émojis que le contrat refusait dès 141, et
 * `'❤️'.repeat(280)` — 560 unités, 560 points de code — passait côté API
 * pour « 280 caractères ». Le mot d'un défi a été corrigé le premier ; le
 * titre d'un défi, le mot d'un encouragement et les précisions d'un
 * signalement avaient le même écart. L'unité retenue est le POINT DE CODE,
 * des deux côtés (`codePointLength`, `@MaxCodePoints`).
 *
 * Chaque cas est donc posé aux DEUX validateurs, qui doivent s'accorder.
 */

type DtoClass = new () => object;

/** Le DTO accepte-t-il ce corps ? (mêmes options que le `ValidationPipe` global) */
function dtoAccepte(dto: DtoClass, body: Record<string, unknown>): boolean {
  const instance = plainToInstance(dto, body);
  return validateSync(instance, { whitelist: true, forbidNonWhitelisted: true }).length === 0;
}

/** Un texte libre, son DTO, son contrat, et un corps valide à compléter. */
interface TexteLibre {
  nom: string;
  champ: string;
  max: number;
  dto: DtoClass;
  contrat: ZodType;
  corps: Record<string, unknown>;
  /** Le contrat découpe-t-il les blancs autour AVANT de mesurer ? */
  decoupe: boolean;
  /** Le champ peut-il manquer ? */
  facultatif: boolean;
}

const INVITE = '0d6f5c3a-2b1e-4c4d-8f7a-6e5d4c3b2a19';
const DEFI = {
  id: '4b0f3f5e-8a8f-4a8c-9a57-2f4c1d3e5b6a',
  title: 'Qui court le plus',
  metric: 'DISTANCE_METERS',
  durationDays: 7,
  invitedUserIds: [INVITE],
};

const TEXTES: TexteLibre[] = [
  {
    nom: 'le mot d’un défi',
    champ: 'message',
    max: FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH,
    dto: CreateFriendChallengeDto,
    contrat: createFriendChallengeRequestSchema,
    corps: DEFI,
    decoupe: true,
    facultatif: true,
  },
  {
    nom: 'le titre d’un défi',
    champ: 'title',
    max: FRIEND_CHALLENGE_TITLE_MAX_LENGTH,
    dto: CreateFriendChallengeDto,
    contrat: createFriendChallengeRequestSchema,
    corps: DEFI,
    decoupe: true,
    facultatif: false,
  },
  {
    nom: 'le mot d’un encouragement',
    champ: 'message',
    max: ENCOURAGEMENT_MESSAGE_MAX_LENGTH,
    dto: EncourageDto,
    contrat: encourageRequestSchema,
    corps: { recipientUserId: INVITE },
    decoupe: false,
    facultatif: false,
  },
  {
    nom: 'les précisions d’un signalement',
    champ: 'details',
    max: COMMUNITY_REPORT_DETAILS_MAX_LENGTH,
    dto: CreateCommunityReportDto,
    contrat: createCommunityReportSchema,
    corps: { reportedUserId: INVITE, reason: 'SPAM' },
    decoupe: false,
    facultatif: true,
  },
];

/** Les cas communs à tous les textes, avec la réponse attendue des deux côtés. */
function cas(texte: TexteLibre): Array<[string, unknown, boolean]> {
  const { max } = texte;
  return [
    [`${max} lettres`, 'x'.repeat(max), true],
    [`${max + 1} lettres`, 'x'.repeat(max + 1), false],
    // Découpé avant d'être mesuré (titre, mot d'un défi) : les blancs
    // autour ne comptent pas. Sinon, ils comptent, des deux côtés.
    [`${max} lettres entourées de blancs`, `  ${'x'.repeat(max)}  `, texte.decoupe],
    // Un émoji simple = un point de code, deux unités UTF-16 : le contrat
    // refusait ce cas, l'API l'acceptait.
    [`${max} émojis simples`, '😀'.repeat(max), true],
    [`${max + 1} émojis simples`, '😀'.repeat(max + 1), false],
    // ❤️ = U+2764 + U+FE0F, deux points de code : l'API comptait un, et
    // stockait jusqu'à deux fois la longueur annoncée.
    [`${max / 2} cœurs avec sélecteur`, '❤️'.repeat(max / 2), true],
    [`${max / 2 + 1} cœurs avec sélecteur`, '❤️'.repeat(max / 2 + 1), false],
    [`${max} émojis suivis d’un sélecteur`, '😀️'.repeat(max), false],
    // Un sélecteur SEUL : un point de code des deux côtés (validator.js
    // n'efface que ceux qui SUIVENT un caractère).
    ['un sélecteur de variante seul', '️', true],
    ['absent', undefined, texte.facultatif],
    ['pas une chaîne', 42, false],
  ];
}

describe.each(TEXTES)('$nom : compté comme le contrat le compte', (texte) => {
  it.each(cas(texte))('%s : les deux validateurs s’accordent', (_cas, valeur, attendu) => {
    const body = { ...texte.corps, [texte.champ]: valeur };
    if (valeur === undefined) {
      delete body[texte.champ];
    }
    expect({
      dto: dtoAccepte(texte.dto, body),
      contrat: texte.contrat.safeParse(body).success,
    }).toEqual({ dto: attendu, contrat: attendu });
  });
});

describe('le mot d’un défi : null et blanc valent « pas de message »', () => {
  it.each([
    ['null', null],
    ['blanc', '   '],
  ])('%s : les deux validateurs acceptent', (_cas, message) => {
    const body = { ...DEFI, message };
    expect({
      dto: dtoAccepte(CreateFriendChallengeDto, body),
      contrat: createFriendChallengeRequestSchema.safeParse(body).success,
    }).toEqual({ dto: true, contrat: true });
  });
});

describe('le titre d’un défi : blanc refusé des deux côtés', () => {
  it('trois espaces ne font pas un titre', () => {
    const body = { ...DEFI, title: '   ' };
    expect({
      dto: dtoAccepte(CreateFriendChallengeDto, body),
      contrat: createFriendChallengeRequestSchema.safeParse(body).success,
    }).toEqual({ dto: false, contrat: false });
  });
});
