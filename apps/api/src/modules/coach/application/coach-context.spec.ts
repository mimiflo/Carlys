import { type AppConfigService } from '../../../config/app-config.service';
import { type ProgramsService } from '../../programs/application/programs.service';
import { type UsersService } from '../../users/application/users.service';
import {
  type ConversationWithMessages,
  type CoachRepository,
} from '../infrastructure/coach.repository';
import { CoachContextBuilder } from './coach-context.builder';
import { memoryBriefing, summaryRequest, trainingBriefing } from './coach-context.prompt';

const message = (i: number) => ({
  id: `m${i}`,
  conversationId: 'c',
  role: i % 2 === 0 ? ('USER' as const) : ('ASSISTANT' as const),
  content: `message ${i}`,
  inputTokens: null,
  outputTokens: null,
  createdAt: new Date(2026, 8, 1, 10, i),
  proposal: null,
  programProposal: null,
});

function builder(training: unknown = null, active: string | null = null) {
  return new CoachContextBuilder(
    {
      voiceOf: jest.fn().mockResolvedValue({ carlysProfile: null, mentorStyle: null }),
    } as unknown as CoachRepository,
    { training: jest.fn().mockResolvedValue(training) } as unknown as UsersService,
    { activeProgramName: jest.fn().mockResolvedValue(active) } as unknown as ProgramsService,
    { coachGateway: { historyMessages: 4 } } as unknown as AppConfigService,
  );
}

/**
 * Le contexte ne recopie jamais tout le fil : profil condensé, mémoire,
 * derniers messages, question — et rien d'autre (ADR 0013, point 7).
 */
describe('CoachContextBuilder', () => {
  it('seulement les N derniers messages, puis la question ; la mémoire et le profil dans le bloc par utilisateur', async () => {
    const conversation = {
      id: 'c',
      summary: 'Objectif : force. Genou gauche fragile.',
      messages: Array.from({ length: 10 }, (_, i) => message(i)),
    } as unknown as ConversationWithMessages;

    const context = await builder(
      {
        trainingGoal: 'STRENGTH',
        trainingExperience: 'INTERMEDIATE',
        weeklySessionsTarget: 3,
        sessionMinutesTarget: 45,
        equipmentSlugs: ['barbell'],
      },
      'Force 5x5',
    ).build('u', conversation, 'nouveau', 'Et demain ?');

    expect(context.history.map((turn) => turn.content.split('\n').at(-1))).toEqual([
      'message 6',
      'message 7',
      'message 8',
      'message 9',
      'Et demain ?',
    ]);
    expect(context.systemPerUser).toContain('objectif STRENGTH');
    expect(context.systemPerUser).toContain('« Force 5x5 »');
    expect(context.systemPerUser).toContain('Genou gauche fragile');
  });

  it('un profil illisible ne bloque rien : le tour part sans lui', async () => {
    const failing = new CoachContextBuilder(
      { voiceOf: jest.fn().mockRejectedValue(new Error('base')) } as unknown as CoachRepository,
      { training: jest.fn().mockRejectedValue(new Error('base')) } as unknown as UsersService,
      { activeProgramName: jest.fn().mockResolvedValue(null) } as unknown as ProgramsService,
      { coachGateway: { historyMessages: 4 } } as unknown as AppConfigService,
    );
    const context = await failing.build(
      'u',
      { id: 'c', summary: null, messages: [] } as unknown as ConversationWithMessages,
      'm',
      'Salut',
    );
    expect(context.systemPerUser).toBe('');
    expect(context.history).toHaveLength(1);
  });

  it('la fenêtre chargée vaut N + 1 (le message du tour peut y figurer)', () => {
    expect(builder().window).toBe(5);
  });
});

describe('blocs du contexte', () => {
  it('profil vide : rien du tout, plutôt qu’une ligne creuse', () => {
    expect(trainingBriefing(null, null)).toBe('');
    expect(
      trainingBriefing(
        {
          trainingGoal: null,
          trainingExperience: null,
          weeklySessionsTarget: null,
          sessionMinutesTarget: null,
          equipmentSlugs: [],
        },
        null,
      ),
    ).toBe('');
  });

  it('pas de mémoire : pas de bloc', () => {
    expect(memoryBriefing(null)).toBe('');
    expect(memoryBriefing('  ')).toBe('');
  });

  it('la demande de résumé porte l’ancienne mémoire et les messages à y fondre', () => {
    const request = summaryRequest('Objectif : force.', [
      { role: 'USER', content: 'Je préfère le matin.' },
      { role: 'ASSISTANT', content: 'Noté.' },
    ]);
    expect(request).toContain('Résumé précédent :\nObjectif : force.');
    expect(request).toContain('Personne : Je préfère le matin.');
    expect(request).toContain('Coach : Noté.');
  });
});
