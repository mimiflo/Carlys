import { restates } from './openai-compatible.helpers';

describe('restates — une redite après l’occasion d’agir', () => {
  // Constaté le 2 octobre 2026 : la même séance deux fois dans la réplique archivée.
  const before =
    'Oui, tu peux t’entraîner même si tu es fatigué. Voici une séance rapide et ciblée : ' +
    '2 séries de 10 répétitions de développé couché à 55 kg, 2 séries de 10 de tractions, ' +
    'puis 2 séries de 15 de pompes. J’ai retiré les charges élevées pour éviter de t’épuiser.';

  it('la même séance réécrite est une redite', () => {
    const again =
      'Voici une séance de 20 minutes : 2 séries de 10 répétitions de développé couché à 55 kg, ' +
      '2 séries de 10 de tractions, puis 2 séries de 15 de pompes. J’ai retiré les charges élevées.';
    expect(restates(again, before)).toBe(true);
  });

  it('une suite nouvelle n’en est pas une', () => {
    expect(
      restates(
        'Je te propose aussi un programme de quatre semaines, trois séances chacune.',
        before,
      ),
    ).toBe(false);
    expect(restates('Tout ce que tu veux.', '')).toBe(false);
  });
});
