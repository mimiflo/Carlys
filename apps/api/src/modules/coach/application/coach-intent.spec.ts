import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { type CoachIntentTurn, resolveIntent } from './coach-intent';

interface Case {
  message: string;
  expected: string;
  context?: 'proposal' | 'asked';
}

const FIXTURES = JSON.parse(
  readFileSync(join(__dirname, '../../../../test/fixtures/coach-intents.json'), 'utf8'),
) as { session: Case[]; other: Case[] };

/** La réplique précédente porte une proposition de séance. */
const WITH_PROPOSAL: CoachIntentTurn[] = [
  { role: 'user', content: 'J’ai seulement 25 minutes aujourd’hui.', proposalId: null },
  {
    role: 'assistant',
    content: 'Tu as 25 minutes : je garde tes deux mouvements lourds.',
    proposalId: 'proposition-1',
  },
];

/** La capture du 2 octobre 2026 : une séance demandée, une réponse sans carte. */
const ASKED = 'tu me conseilles, quoi en séance quad fessiers ?';
const ASKED_WITHOUT_CARD: CoachIntentTurn[] = [
  { role: 'user', content: ASKED, proposalId: null },
  {
    role: 'assistant',
    content: 'Je te conseille le squat au poids du corps, puis le pont fessier.',
    proposalId: null,
  },
];

const contextOf = (kind: Case['context']) =>
  kind === 'proposal' ? WITH_PROPOSAL : kind === 'asked' ? ASKED_WITHOUT_CARD : [];

describe('resolveIntent', () => {
  it.each(FIXTURES.session)('« $message » : $expected', ({ message, expected, context }) => {
    expect(resolveIntent(message, contextOf(context)).kind).toBe(expected);
  });

  it.each(FIXTURES.other)('« $message » : $expected', ({ message, expected, context }) => {
    expect(resolveIntent(message, contextOf(context)).kind).toBe(expected);
  });

  it('« Ok crée-la » reprend la DERNIÈRE proposition : rien à redemander', () => {
    expect(resolveIntent('Ok crée-la.', WITH_PROPOSAL)).toEqual({
      kind: 'WORKOUT_CREATION_REQUIRED',
      proposalId: 'proposition-1',
      request: null,
      minutes: null,
    });
  });

  it('« Crée-la en 30 min » : la carte en vue, ramenée à 30 min, puis créée', () => {
    expect(resolveIntent('Crée-la en 30 min.', WITH_PROPOSAL)).toEqual({
      kind: 'WORKOUT_CREATION_REQUIRED',
      proposalId: 'proposition-1',
      request: 'Crée-la en 30 min.',
      minutes: 30,
    });
  });

  it('une création qui décrit sa séance la compose, même après une proposition', () => {
    expect(resolveIntent('Crée-moi une séance jambes.', WITH_PROPOSAL)).toMatchObject({
      kind: 'WORKOUT_CREATION_REQUIRED',
      proposalId: null,
      request: 'Crée-moi une séance jambes.',
    });
  });

  it('« ça fait 5 fois que je te demande » : la séance demandée plus haut, créée', () => {
    expect(
      resolveIntent(
        'Ça me rend fou ton truc, ça fait 5 fois que je te demande de créer une séance.',
        ASKED_WITHOUT_CARD,
      ),
    ).toMatchObject({ kind: 'WORKOUT_CREATION_REQUIRED', proposalId: null, request: ASKED });
  });

  it('la frustration sans verbe reprend la dernière demande d’action', () => {
    expect(
      resolveIntent('Ça marche jamais ton truc, je te l’ai demandé 5 fois !', ASKED_WITHOUT_CARD),
    ).toMatchObject({ kind: 'WORKOUT_PROPOSAL_REQUIRED', request: ASKED });
  });

  it('le temps disponible se lit : il borne la séance', () => {
    expect(resolveIntent('J’ai 20 minutes, je fais quoi ?', [])).toMatchObject({ minutes: 20 });
    expect(resolveIntent('Une séance express de 15 min ?', [])).toMatchObject({ minutes: 15 });
    expect(resolveIntent('Une séance dos ?', [])).toMatchObject({ minutes: null });
  });

  it('modifier la proposition : elle sert de base, la demande dit quoi changer', () => {
    expect(resolveIntent('Et si je n’ai que 20 minutes ?', WITH_PROPOSAL)).toEqual({
      kind: 'WORKOUT_MODIFICATION_REQUIRED',
      proposalId: 'proposition-1',
      request: 'Et si je n’ai que 20 minutes ?',
      minutes: 20,
    });
  });

  it('rien à créer : UNE question précise, jamais une création au hasard', () => {
    const intent = resolveIntent('Ok crée-la.', []);
    expect(intent.kind).toBe('CLARIFICATION_REQUIRED');
    expect(intent.kind === 'CLARIFICATION_REQUIRED' && intent.question).toMatch(/\?$/);
  });

  it('une proposition trop ancienne (au-delà des derniers échanges) ne se reprend pas', () => {
    const old: CoachIntentTurn[] = [
      ...WITH_PROPOSAL,
      { role: 'user', content: 'Et pour manger ?', proposalId: null },
      { role: 'assistant', content: 'Des protéines à chaque repas.', proposalId: null },
      { role: 'user', content: 'Et dormir ?', proposalId: null },
      { role: 'assistant', content: 'Huit heures.', proposalId: null },
    ];
    expect(resolveIntent('Ok crée-la.', old).kind).toBe('CLARIFICATION_REQUIRED');
  });
});
