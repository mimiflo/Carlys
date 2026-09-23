import {
  createFriendChallengeRequestSchema,
  FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH,
} from '@carlys/api-contracts';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { CreateFriendChallengeDto } from './community.dto';

/**
 * CE QUE CE FICHIER PROTÈGE : l'API et le contrat qu'elle publie disent la
 * MÊME chose de la longueur du mot d'un défi.
 *
 * Ils ne le disaient pas. `@MaxLength` (validator.js) compte une paire de
 * substitution pour un et efface les sélecteurs de variante ; le contrat
 * (`z.string().max()`) comptait les unités UTF-16. Même constante, deux
 * règles : l'API acceptait 280 émojis que le contrat refusait dès 141, et
 * `'❤️'.repeat(280)` — 560 unités, 560 points de code — passait côté API
 * pour « 280 caractères ». L'unité retenue est le POINT DE CODE, des deux
 * côtés (`codePointLength`).
 *
 * Chaque cas est donc posé aux DEUX validateurs, qui doivent s'accorder.
 */

const MAX = FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH;

const corps = (message: unknown) => ({
  id: '4b0f3f5e-8a8f-4a8c-9a57-2f4c1d3e5b6a',
  title: 'Qui court le plus',
  metric: 'DISTANCE_METERS',
  durationDays: 7,
  invitedUserIds: ['0d6f5c3a-2b1e-4c4d-8f7a-6e5d4c3b2a19'],
  message,
});

/** Le DTO accepte-t-il ce mot ? (mêmes options que le `ValidationPipe` global) */
function dtoAccepte(message: unknown): boolean {
  const dto = plainToInstance(CreateFriendChallengeDto, corps(message));
  return validateSync(dto, { whitelist: true, forbidNonWhitelisted: true }).length === 0;
}

function contratAccepte(message: unknown): boolean {
  return createFriendChallengeRequestSchema.safeParse(corps(message)).success;
}

describe('CreateFriendChallengeDto — le mot, compté comme le contrat le compte', () => {
  it.each([
    [`${MAX} lettres`, 'x'.repeat(MAX), true],
    [`${MAX + 1} lettres`, 'x'.repeat(MAX + 1), false],
    [`${MAX} lettres entourées de blancs`, `  ${'x'.repeat(MAX)}  `, true],
    // Un émoji simple = un point de code, deux unités UTF-16 : le contrat
    // refusait ce cas, l'API l'acceptait.
    [`${MAX} émojis simples`, '😀'.repeat(MAX), true],
    [`${MAX + 1} émojis simples`, '😀'.repeat(MAX + 1), false],
    // ❤️ = U+2764 + U+FE0F, deux points de code : l'API comptait un, et
    // stockait jusqu'à deux fois la longueur annoncée.
    [`${MAX / 2} cœurs avec sélecteur`, '❤️'.repeat(MAX / 2), true],
    [`${MAX / 2 + 1} cœurs avec sélecteur`, '❤️'.repeat(MAX / 2 + 1), false],
    [`${MAX} émojis suivis d’un sélecteur`, '😀️'.repeat(MAX), false],
    ['absent', undefined, true],
    ['null', null, true],
    ['blanc', '   ', true],
    ['pas une chaîne', 42, false],
  ])('%s : les deux validateurs s’accordent', (_cas, message, attendu) => {
    expect({ dto: dtoAccepte(message), contrat: contratAccepte(message) }).toEqual({
      dto: attendu,
      contrat: attendu,
    });
  });
});
