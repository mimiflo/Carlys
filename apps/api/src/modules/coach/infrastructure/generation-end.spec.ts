import { endOfCompletion, looksSuspended } from './generation-end';

const ended = (finish_reason: string) => ({ choices: [{ finish_reason, message: {} }] });

describe('endOfCompletion — la fin déclarée par le moteur', () => {
  it('length : coupée par le plafond ; stop : fin voulue', () => {
    expect(endOfCompletion(ended('length'))).toBe('MAX_TOKENS');
    expect(endOfCompletion(ended('stop'))).toBe('NORMAL_STOP');
    expect(endOfCompletion(ended('tool_calls'))).toBe('NORMAL_STOP');
    expect(endOfCompletion({})).toBe('UNKNOWN');
  });
});

describe('looksSuspended — une fin manifestement en suspens, malgré un stop', () => {
  it('reconnaît les signaux de syntaxe', () => {
    for (const cut of [
      // I. constatée : un mot-outil, et plus rien.
      'Le développé couché permet de travailler principalement les',
      'Voici les trois exercices :',
      'Commence par le squat,',
      'Ta séance :\n1. Squat 3×8\n2.',
      'Garde une charge modérée (environ 70 % de ton max',
      '```\nsquat 3x8',
      'Je te conseille ensuite de',
      // II. Constatées au banc : une phrase arrêtée sur un mot plein.
      'Le développé couché travaille',
      'Parce que ça relâche les muscles tendus, prévient les douleurs et améliore',
      'Un squat bien fait renforce les quadriceps. Si tu as un enregistrement récent',
    ]) {
      expect(looksSuspended(cut)).toBe(true);
    }
  });

  it('laisse passer les vraies fins, même courtes (C, H)', () => {
    for (const done of [
      'Oui, c’est possible.',
      'Avec plaisir !',
      'Ta séance :\n1. Squat 3×8\n2. Pompes 3×12\n3. Gainage 3×30 s',
      'Bonne séance 💪',
      'Tu veux que je te prépare une séance ?',
      'Repos : 90 secondes (pas plus).',
      'Garde 70 kg cette semaine.',
      // Une liste, un titre : leur dernière ligne n'est pas une phrase.
      'Ta séance :\n- Squat 3×8\n- Pompes 3×12',
      'Bonne séance !\n\n### Récupération',
      '**Bonne séance**',
      '',
    ]) {
      expect(looksSuspended(done)).toBe(false);
    }
  });
});
