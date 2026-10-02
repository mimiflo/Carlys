import { coachSteps } from './coach-steps';

describe('coachSteps — la réflexion, nommée depuis les vrais appels', () => {
  it('une étape par outil connu, une seule fois, dans l’ordre', () => {
    const steps = coachSteps();

    expect(steps.add([{ name: 'get_personal_records' }, { name: 'get_personal_records' }])).toEqual(
      ['Je regarde tes records'],
    );
    expect(steps.add([{ name: 'get_personal_records' }, { name: 'propose_program' }])).toEqual([
      'Je prépare ton programme',
    ]);
    // Un outil inconnu ne s'invente pas d'étape, pas même un nom d'objet.
    expect(
      steps.add([{ name: 'outil_inconnu' }, { name: 'toString' }, { name: 'constructor' }]),
    ).toEqual([]);
    expect(steps.all({ session: false, program: true })).toEqual([
      'Je regarde tes records',
      'Je prépare ton programme',
    ]);
    // Une proposition rejetée par la validation : son « Je prépare… » ne s'archive pas.
    expect(steps.all({ session: false, program: false })).toEqual(['Je regarde tes records']);
  });
});
