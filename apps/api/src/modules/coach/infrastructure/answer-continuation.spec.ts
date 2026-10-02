import { type FinishReason } from '../domain/coach-model.port';
import { type Complete, completeAnswer } from './answer-continuation';
import { AnswerStream, atWordBoundary, continuationPrompt, saysFin, stitch } from './answer-stream';
import { GenerationFailure } from './generation-end';

describe('atWordBoundary — repartir d’un mot entier', () => {
  it('retire le dernier mot peut-être coupé, rien d’autre', () => {
    expect(atWordBoundary('en fonction de l’é')).toBe('en fonction de ');
    expect(atWordBoundary('principalement les')).toBe('principalement ');
    expect(atWordBoundary('Fin de phrase.')).toBe('Fin de phrase.');
    expect(atWordBoundary('Liste :\n')).toBe('Liste :\n');
  });
});

describe('stitch — une seule réponse, sans doublon à la jointure (G)', () => {
  it('le recouvrement répété est retiré', () => {
    expect(stitch('puis passe au développé incliné', 'développé incliné avec 3 séries.')).toBe(
      'puis passe au développé incliné avec 3 séries.',
    );
    // Sans casse ni ponctuation.
    expect(stitch('Commence par le Squat', 'squat barre : 3 séries de 8.')).toBe(
      'Commence par le Squat barre : 3 séries de 8.',
    );
  });

  it('sans recouvrement, la suite s’ajoute telle quelle', () => {
    expect(stitch('Je te conseille ensuite de ', 'passer aux tractions.')).toBe(
      'Je te conseille ensuite de passer aux tractions.',
    );
    expect(stitch('travailler principalement', 'les pectoraux.')).toBe(
      'travailler principalement les pectoraux.',
    );
    expect(stitch('Voici :\n', '- squat')).toBe('Voici :\n- squat');
  });

  it('ne réécrit jamais le reste : le résultat commence par la réponse partielle', () => {
    const previous = 'Le squat travaille les cuisses. Le squat travaille aussi';
    expect(stitch(previous, 'les fessiers.')?.startsWith(previous)).toBe(true);
    // Un mot répété AU MILIEU de la suite n'est pas touché.
    expect(stitch('Fais du squat ', 'puis encore du squat.')).toBe(
      'Fais du squat puis encore du squat.',
    );
  });

  it('une suite vide ou entièrement répétée ne change rien', () => {
    expect(stitch('Fin de la séance', 'séance')).toBe('Fin de la séance');
    expect(stitch('Bonjour', '   ')).toBe('Bonjour');
  });
});

describe('stitch — ce que Qwen3-4B fait vraiment d’une reprise (mesuré)', () => {
  it('il réécrit la fin de phrase : la suite repart après les derniers mots retrouvés', () => {
    expect(
      stitch(
        'en augmentant la charge (le poids), le nombre de ',
        'en augmentant le nombre de répétitions ou la durée de l’effort.',
      ),
    ).toBe('en augmentant la charge (le poids), le nombre de répétitions ou la durée de l’effort.');
  });

  it('il recommence la réponse : gardée seulement après ses derniers mots, retrouvés', () => {
    const previous =
      'La surcharge progressive consiste à augmenter la difficulté. Tu commences par une ';
    expect(
      stitch(
        previous,
        'La surcharge progressive consiste à augmenter la difficulté de ton entraînement. Tu commences par une charge stable.',
      ),
    ).toBe(`${previous}charge stable.`);
    // Sans eux, rien ne se raccorde : jamais la réponse deux fois.
    expect(
      stitch(previous, 'La surcharge progressive consiste à augmenter les charges peu à peu.'),
    ).toBeNull();
  });

  it('les retours à la ligne de la suite sont gardés ; une ponctuation dite deux fois ne l’est pas', () => {
    expect(stitch('Voici ta séance :\n1. Squat', 'Squat 3×8\n2. Pompes 3×12')).toBe(
      'Voici ta séance :\n1. Squat 3×8\n2. Pompes 3×12',
    );
    expect(stitch('en respectant un rythme :', ': une hausse de 5 % par semaine.')).toBe(
      'en respectant un rythme : une hausse de 5 % par semaine.',
    );
  });
});

describe('saysFin', () => {
  it('« FIN » seul : la réponse était complète', () => {
    expect(saysFin('FIN')).toBe(true);
    expect(saysFin(' fin. ')).toBe(true);
    expect(saysFin('Fin de la séance : étirements.')).toBe(false);
  });
});

/** Un appel scripté : ses morceaux de texte, sa fin, ses appels d'outils, ou sa panne. */
interface Step {
  text?: string[];
  finish?: string;
  calls?: { id: string; function?: { name?: string; arguments?: unknown } }[];
  fail?: FinishReason;
  /** La personne annule pendant l'appel. */
  cancel?: AbortController;
}

function model(steps: Step[]) {
  const sent: Record<string, unknown>[][] = [];
  const complete = jest.fn<ReturnType<Complete>, Parameters<Complete>>(
    (payload, _signal, onText) => {
      sent.push(payload.messages as Record<string, unknown>[]);
      const step = steps.shift();
      if (step === undefined) return Promise.reject(new Error('appel de trop'));
      const text = step.text ?? [];
      // Sans flux, le texte n'arrive qu'avec la complétion.
      for (const delta of text) onText?.(delta);
      step.cancel?.abort();
      if (step.cancel) return Promise.reject(new DOMException('annulé', 'AbortError'));
      if (step.fail) return Promise.reject(new GenerationFailure('panne', step.fail));
      return Promise.resolve({
        served: 'worker-1',
        completion: {
          choices: [
            {
              finish_reason: step.finish ?? 'stop',
              message: { content: text.join(''), tool_calls: step.calls ?? [] },
            },
          ],
          usage: { prompt_tokens: 100, completion_tokens: 10 },
        },
      });
    },
  );
  return { complete, sent };
}

const QUESTION = [{ role: 'user', content: 'Le développé couché, ça travaille quoi ?' }];

async function answer(
  steps: Step[],
  options: { stream?: boolean; cancelled?: AbortController; trustStop?: boolean } = {},
) {
  const { complete, sent } = model(steps);
  const shown: string[] = [];
  const usage = { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0 };
  const result = await completeAnswer(complete, {
    messages: QUESTION,
    tools: [],
    signal: new AbortController().signal,
    cancelled: options.cancelled?.signal,
    onText: options.stream === false ? undefined : (delta) => shown.push(delta),
    maxTokens: 64,
    worker: undefined,
    maxContinuations: 2,
    trustStop: options.trustStop ?? false,
    usage,
  });
  const text = result.completion.choices?.[0]?.message?.content;
  return { ...result, text, shown: shown.join(''), calls: complete.mock.calls.length, sent, usage };
}

describe('completeAnswer — une réponse coupée reprend, une réponse finie part telle quelle', () => {
  it('A. coupée par le plafond (`length`) : la suite est demandée, raccordée, dans la même bulle', async () => {
    const result = await answer([
      { text: ['Le développé couché travaille ', 'les pectoraux, les tri'], finish: 'length' },
      { text: ['triceps et l’avant des épaules. Garde les omoplates serrées sur le banc.'] },
    ]);

    expect(result.text).toBe(
      'Le développé couché travaille les pectoraux, les triceps et l’avant des épaules. Garde les omoplates serrées sur le banc.',
    );
    // Ce qui est montré EST la réponse : un seul message, sans « Suite ».
    expect(result.shown).toBe(result.text);
    expect(result.report).toEqual({
      ends: ['MAX_TOKENS', 'NORMAL_STOP'],
      continuations: 1,
      recovered: 1,
      unneeded: 0,
      truncated: false,
    });
    // La suite part du dernier mot ENTIER, avec la consigne interne.
    expect(result.sent[1]?.slice(-2)).toEqual([
      { role: 'assistant', content: 'Le développé couché travaille les pectoraux, les ' },
      {
        role: 'user',
        content: continuationPrompt('Le développé couché travaille les pectoraux, les '),
      },
    ]);
    expect(result.usage.outputTokens).toBe(20);
  });

  it('B. une réponse complète (`stop`) : aucun second appel', async () => {
    const full =
      'Le développé couché travaille surtout les pectoraux, puis les triceps et l’avant des épaules.';
    const result = await answer([{ text: [full] }]);

    expect(result.calls).toBe(1);
    expect(result.text).toBe(full);
    expect(result.shown).toBe(full);
    expect(result.report.continuations).toBe(0);
  });

  it('C. une réponse courte et complète : aucune reprise', async () => {
    for (const short of [
      'Oui.',
      'Avec plaisir !',
      'Bonne séance 💪',
      'Garde 70 kg cette semaine',
    ]) {
      const result = await answer([{ text: [short] }]);
      expect(result.calls).toBe(1);
      expect(result.text).toBe(short);
    }
  });

  it('D. un appel d’outil n’est jamais une coupure, même annoncé par « : »', async () => {
    const call = {
      id: 'c1',
      type: 'function',
      function: { name: 'search_exercises', arguments: '{}' },
    };
    const result = await answer([
      { text: ['Je cherche les exercices :'], calls: [call], finish: 'tool_calls' },
    ]);

    expect(result.calls).toBe(1);
    expect(result.completion.choices?.[0]?.message?.tool_calls).toEqual([call]);
    expect(result.report.continuations).toBe(0);
  });

  it('E. une panne récupérable (flux muet) après du texte : la réponse reprend de ce texte', async () => {
    const result = await answer([
      { text: ['Commence par 10 minutes de '], fail: 'TIMEOUT' },
      { text: ['de vélo, puis trois séries de squats légers.'] },
    ]);

    expect(result.text).toBe(
      'Commence par 10 minutes de vélo, puis trois séries de squats légers.',
    );
    expect(result.shown).toBe(result.text);
    expect(result.report.ends).toEqual(['TIMEOUT', 'NORMAL_STOP']);
    expect(result.report.recovered).toBe(1);
  });

  it('E bis. une panne AVANT tout texte remonte : rien à reprendre', async () => {
    await expect(answer([{ fail: 'WORKER_ERROR' }])).rejects.toBeInstanceOf(GenerationFailure);
  });

  it('F. deux reprises, une seule réponse finale', async () => {
    const result = await answer([
      {
        text: ['Semaine 1 : trois séances de corps entier, avec des charges modé'],
        finish: 'length',
      },
      {
        text: [
          'modérées et une progression de 2,5 kg par séance sur les mouvements de base. Semaine 2 : ajoute une sé',
        ],
        finish: 'length',
      },
      { text: ['séance de cardio léger.'] },
    ]);

    expect(result.text).toBe(
      'Semaine 1 : trois séances de corps entier, avec des charges modérées et une progression de 2,5 kg par séance sur les mouvements de base. Semaine 2 : ajoute une séance de cardio léger.',
    );
    expect(result.shown).toBe(result.text);
    expect(result.report).toMatchObject({ continuations: 2, recovered: 1, truncated: false });
  });

  it('G. les derniers mots répétés par la reprise ne sont pas doublés', async () => {
    const result = await answer([
      { text: ['Fais 3 séries, puis passe au développé incliné avec halt'], finish: 'length' },
      {
        text: [
          'développé incliné avec haltères, 3 séries de 10 répétitions en contrôlant la descente.',
        ],
      },
    ]);

    expect(result.text).toBe(
      'Fais 3 séries, puis passe au développé incliné avec haltères, 3 séries de 10 répétitions en contrôlant la descente.',
    );
    expect(result.shown).toBe(result.text);
  });

  it('H. une liste complète n’est pas reprise', async () => {
    const list = 'Ta séance :\n1. Squat 3×8\n2. Pompes 3×12\n3. Gainage 3×30 s';
    const result = await answer([{ text: [list] }]);

    expect(result.calls).toBe(1);
    expect(result.text).toBe(list);
  });

  it('I. une fin en suspens malgré `stop` est reprise', async () => {
    const result = await answer([
      { text: ['Pour progresser, je te conseille de'] },
      { text: ['varier les charges chaque semaine.'] },
    ]);

    expect(result.text).toBe(
      'Pour progresser, je te conseille de varier les charges chaque semaine.',
    );
    expect(result.shown).toBe(result.text);
    expect(result.report.ends).toEqual(['NORMAL_STOP', 'NORMAL_STOP']);
  });

  it('I bis. reprise superflue : « FIN » laisse la réponse intacte, comptée comme telle', async () => {
    const result = await answer([{ text: ['Voici les trois exercices :'] }, { text: ['FIN'] }]);

    expect(result.text).toBe('Voici les trois exercices :');
    expect(result.shown).toBe(result.text);
    expect(result.report).toMatchObject({ continuations: 1, recovered: 0, unneeded: 1 });
  });

  it('I ter. une proposition déjà faite : « Voici la séance : » ne se reprend pas', async () => {
    const result = await answer([{ text: ['Voici la séance que je te propose :'] }], {
      trustStop: true,
    });
    expect(result.calls).toBe(1);
  });

  it('J. annulée par la personne : AUCUNE reprise', async () => {
    const cancelled = new AbortController();
    await expect(
      answer([{ text: ['Le développé couché travaille '], cancel: cancelled }], { cancelled }),
    ).rejects.toThrow('annulé');
  });

  it('une reprise qui recommence sans rejoindre la réponse est écartée, une autre la remplace', async () => {
    const result = await answer([
      {
        text: ['Le développé couché travaille surtout les pectoraux, puis les tri'],
        finish: 'length',
      },
      { text: ['Le développé couché travaille surtout le haut du corps.'] },
      { text: ['triceps et l’avant des épaules.'] },
    ]);

    expect(result.text).toBe(
      'Le développé couché travaille surtout les pectoraux, puis les triceps et l’avant des épaules.',
    );
    expect(result.shown).toBe(result.text);
    expect(result.report).toMatchObject({ continuations: 2, recovered: 1, truncated: false });
  });

  it('plafond de reprises atteint : la réponse est rendue, coupée net au dernier mot entier', async () => {
    const result = await answer([
      { text: ['Un très long plan qui ne finit '], finish: 'length' },
      { text: ['jamais vraiment, car il continue encore '], finish: 'length' },
      { text: ['et encore sans jamais conclure sa phr'], finish: 'length' },
    ]);

    expect(result.text).toBe(
      'Un très long plan qui ne finit jamais vraiment, car il continue encore et encore sans jamais conclure sa…',
    );
    expect(result.shown).toBe(result.text);
    expect(result.report).toMatchObject({ continuations: 2, truncated: true });
  });

  it('une reprise impossible (contexte plein) rend la réponse montrée, incomplète', async () => {
    const result = await answer([
      { text: ['Garde le dos droit et '], finish: 'length' },
      { fail: 'CONTEXT_LIMIT' },
    ]);

    // L'espace finale est déjà montrée : « … » s'y ajoute.
    expect(result.text).toBe('Garde le dos droit et …');
    expect(result.shown).toBe(result.text);
    expect(result.report).toMatchObject({ ends: ['MAX_TOKENS', 'CONTEXT_LIMIT'], truncated: true });
  });

  it('sans flux, la même reprise', async () => {
    const result = await answer(
      [
        { text: ['Le développé couché travaille les pectoraux, les tri'], finish: 'length' },
        { text: ['triceps et les épaules.'] },
      ],
      { stream: false },
    );
    expect(result.text).toBe(
      'Le développé couché travaille les pectoraux, les triceps et les épaules.',
    );
  });
});

describe('AnswerStream — ce qui est montré ne se reprend jamais', () => {
  it('retient le dernier mot jusqu’à ce qu’il soit fini', () => {
    const shown: string[] = [];
    const stream = new AnswerStream((delta) => shown.push(delta));
    stream.push('Bon');
    stream.push('jour Lé');
    expect(shown.join('')).toBe('Bonjour ');
    stream.push('a.');
    stream.flush();
    expect(shown.join('')).toBe('Bonjour Léa.');
  });
});
