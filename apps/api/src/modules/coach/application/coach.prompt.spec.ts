import { COACH_SYSTEM_PROMPT, looksVolatile, volatileContext } from './coach.prompt';
import { COACH_TOOLS, PROPOSE_SESSION_TOOL } from './coach.tools';

/**
 * Préfixe mis en cache et périmètre du coach.
 *
 * Deux pièges silencieux sont gardés ici : une donnée volatile glissée dans le
 * préfixe (rien n'échoue, la facture double), et un prompt qui oublierait de
 * dire ce que le coach ne sait pas (il inventerait pour combler).
 */
describe('Prompt du coach', () => {
  it('le préfixe mis en cache ne contient aucune donnée volatile', () => {
    // Le fournisseur met en cache outils + prompt système. Une date, une heure
    // ou un identifiant dans ce bloc invalide la relecture à chaque appel.
    const prefix = COACH_SYSTEM_PROMPT + JSON.stringify(COACH_TOOLS);

    expect(looksVolatile(prefix)).toBe(false);
  });

  it('le rappel de date vit APRÈS la césure, dans le message', () => {
    const context = volatileContext(new Date('2026-08-09T10:00:00.000Z'));

    expect(context).toContain('2026-08-09');
    // Il est volatile par nature : sa place est dans le message, pas au-dessus.
    expect(looksVolatile(context)).toBe(true);
  });

  it('le prompt énonce ce que le coach IGNORE', () => {
    // Sans ces bornes, le modèle comble les vides avec du plausible.
    expect(COACH_SYSTEM_PROMPT).toContain('journal alimentaire');
    expect(COACH_SYSTEM_PROMPT).toContain('sommeil');
    expect(COACH_SYSTEM_PROMPT).toContain('professionnel de santé');
    expect(COACH_SYSTEM_PROMPT).toContain("N'invente jamais");
  });

  it('le prompt interdit les identifiants d’exercice inventés', () => {
    expect(COACH_SYSTEM_PROMPT).toContain('exerciseId');
  });

  it('chaque outil dit QUAND l’appeler, pas seulement ce qu’il fait', () => {
    for (const tool of COACH_TOOLS) {
      expect(tool.description.length).toBeGreaterThan(60);
      expect(tool.description).toMatch(/Appelle-le|ATTENTION|N’écrit RIEN/);
    }
  });

  it('un seul outil produit une sortie structurée, et il n’écrit rien', () => {
    const names = COACH_TOOLS.map((tool) => tool.name);

    expect(names).toContain(PROPOSE_SESSION_TOOL);
    // Aucun autre outil ne porte un verbe d'écriture : le coach ne mute rien.
    const writers = names.filter((name) => /^(create|update|delete|save|add|set)_/.test(name));
    expect(writers).toEqual([]);
  });

  it('looksVolatile repère les trois formes qui cassent le cache', () => {
    expect(looksVolatile('nous sommes le 2026-08-09')).toBe(true);
    expect(looksVolatile('il est 14:32')).toBe(true);
    expect(looksVolatile('requête 3f2504e0-4f89-41d3-9a0c-0305e82c3301')).toBe(true);
    expect(looksVolatile('Tu es le coach de Carlys.')).toBe(false);
  });
});
