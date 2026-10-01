import { EXERCISES } from '../../exercises/application/catalog-data';
import { frenchExerciseNames, frenchExerciseNamesStream } from './coach-exercise-names';

/**
 * « Comme le squat, le deadlift ou le press de poitrine » (Qwen3-4B, 1er
 * octobre 2026) : des noms que l'application ne connaît pas. Ils doivent
 * arriver sous leur nom du catalogue, à l'écran comme dans l'historique.
 */
describe('frenchExerciseNames', () => {
  it('la phrase constatée parle la langue du catalogue', () => {
    expect(
      frenchExerciseNames(
        'On commence par des mouvements de fond, comme le squat, le deadlift ou le press de poitrine.',
      ),
    ).toBe(
      'On commence par des mouvements de fond, comme le squat, le soulevé de terre ou le développé couché.',
    );
  });

  it('les termes courants, majuscule et pluriel compris', () => {
    expect(frenchExerciseNames('Deadlift : 3 séries de 5.')).toBe(
      'Soulevé de terre : 3 séries de 5.',
    );
    expect(frenchExerciseNames('des pull-ups et des push ups')).toBe('des tractions et des pompes');
    expect(frenchExerciseNames('Le bench press, puis le romanian deadlift.')).toBe(
      'Le développé couché, puis le soulevé de terre roumain.',
    );
    expect(frenchExerciseNames('un overhead press avec deux dumbbells')).toBe(
      'un développé militaire avec deux haltères',
    );
  });

  it('aucun nom du catalogue n’est touché', () => {
    for (const { name } of EXERCISES) {
      expect(frenchExerciseNames(name)).toBe(name);
    }
  });

  it('jamais un morceau de mot : « deadlifting » ou « pushup-like » restent tels quels', () => {
    expect(frenchExerciseNames('le deadlifting')).toBe('le deadlifting');
    expect(frenchExerciseNames('compression')).toBe('compression');
  });

  it('un sigle ne capitalise rien, une élision suit le français', () => {
    expect(frenchExerciseNames('Fais des RDL.')).toBe('Fais des soulevé de terre roumain.');
    expect(frenchExerciseNames('Travaille l’overhead press.')).toBe(
      'Travaille le développé militaire.',
    );
    expect(frenchExerciseNames("Prends l'dumbbell")).toBe("Prends l'haltère");
  });

  it('les formes au singulier dont l’article changerait de genre ne bougent pas', () => {
    expect(frenchExerciseNames('un pull-up')).toBe('un pull-up');
  });
});

describe('frenchExerciseNamesStream', () => {
  function streamed(chunks: string[]): string {
    let out = '';
    const names = frenchExerciseNamesStream((text) => (out += text));
    for (const chunk of chunks) names.push(chunk);
    names.flush();
    return out;
  }

  it('un terme coupé entre deux morceaux est réécrit quand même', () => {
    expect(streamed(['le dead', 'lift ou le ', 'press de ', 'poitr', 'ine.'])).toBe(
      'le soulevé de terre ou le développé couché.',
    );
    expect(streamed(['Le bench', ' press', ' et le ', 'Push Press.'])).toBe(
      'Le développé couché et le Push Press.',
    );
  });

  it('chaque découpage rend le même texte que la réécriture d’un bloc', () => {
    const text =
      'Fais du squat, du deadlift, des pull-ups, du bench press puis du press de poitrine, et un Plank jack. ' +
      'Puis le **bench press**, (bench press) et l’overhead press.';
    for (let size = 1; size <= 12; size++) {
      const chunks = text.match(new RegExp(`[\\s\\S]{1,${size}}`, 'g')) ?? [];
      expect(streamed(chunks)).toBe(frenchExerciseNames(text));
    }
  });

  it('une fin de phrase part aussitôt : la fin d’un tour n’attend pas le suivant', () => {
    const out: string[] = [];
    const names = frenchExerciseNamesStream((text) => out.push(text));
    names.push('Je vais t’adapter une séance.');
    expect(out.join('')).toBe('Je vais t’adapter une séance.');
  });

  it('le texte ordinaire part aussitôt, au mot près', () => {
    const out: string[] = [];
    const names = frenchExerciseNamesStream((text) => out.push(text));
    names.push('Bonjour Clarisse, ');
    names.push('on y va');
    expect(out.join('')).toBe('Bonjour Clarisse, on y ');
    names.flush();
    expect(out.join('')).toBe('Bonjour Clarisse, on y va');
  });
});
