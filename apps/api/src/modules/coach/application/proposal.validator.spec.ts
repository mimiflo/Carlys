import { WorkoutSetKind } from '@prisma/client';
import { validateProposal } from './proposal.validator';

/**
 * Validation d'une séance proposée.
 *
 * C'est le garde-fou central du coach : **il ne peut pas inventer**. Tout ce
 * qui est vérifié ici l'est parce qu'un modèle peut le produire — un exercice
 * plausible mais inexistant, une charge délirante, des positions à trous.
 */
describe('validateProposal', () => {
  const DEVELOPPE = '11111111-1111-4111-8111-111111111111';
  const TIRAGE = '22222222-2222-4222-8222-222222222222';

  const catalogue = new Map([
    [DEVELOPPE, 'Développé couché'],
    [TIRAGE, 'Tirage horizontal'],
  ]);

  const item = (overrides: Record<string, unknown> = {}) => ({
    exercisePosition: 0,
    exerciseId: DEVELOPPE,
    setPosition: 0,
    kind: 'NORMAL',
    targetReps: 8,
    targetWeightKg: 60,
    restSeconds: 90,
    ...overrides,
  });

  const proposal = (items: unknown[]) => ({
    name: 'Haut du corps — format court',
    estimatedMinutes: 25,
    items,
  });

  it('accepte une proposition dont chaque exercice existe', () => {
    const result = validateProposal(proposal([item(), item({ setPosition: 1 })]), catalogue);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.proposal.items).toHaveLength(2);
    expect(result.proposal.items[0]?.kind).toBe(WorkoutSetKind.NORMAL);
  });

  it('rejette la proposition entière dès qu’un exercice est inventé', () => {
    // Le cas qui justifie tout le reste : un identifiant crédible, absent du
    // catalogue. On préfère une réponse sans séance à une séance inventée.
    const result = validateProposal(
      proposal([
        item(),
        item({ setPosition: 1, exerciseId: '33333333-3333-4333-8333-333333333333' }),
      ]),
      catalogue,
    );

    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.reason).toContain('n’existe pas au catalogue');
  });

  it('prend le nom au catalogue, jamais celui annoncé par le modèle', () => {
    const result = validateProposal(proposal([item({ exerciseName: 'Squat bulgare' })]), catalogue);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    // Le modèle ne peut pas renommer un exercice en le proposant.
    expect(result.proposal.items[0]?.exerciseName).toBe('Développé couché');
  });

  it('refuse une proposition vide', () => {
    expect(validateProposal(proposal([]), catalogue).ok).toBe(false);
  });

  it('refuse les charges et répétitions absurdes', () => {
    expect(validateProposal(proposal([item({ targetWeightKg: 900 })]), catalogue).ok).toBe(false);
    expect(validateProposal(proposal([item({ targetWeightKg: -10 })]), catalogue).ok).toBe(false);
    expect(validateProposal(proposal([item({ targetReps: 500 })]), catalogue).ok).toBe(false);
  });

  it('refuse des positions à trous', () => {
    // Sans contiguïté, l'écran afficherait des vides et l'unicité en base
    // sauterait au moment d'écrire.
    const result = validateProposal(
      proposal([item(), item({ exercisePosition: 2, exerciseId: TIRAGE })]),
      catalogue,
    );

    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.reason).toContain('ne se suivent pas');
  });

  it('refuse deux séries à la même place', () => {
    const result = validateProposal(proposal([item(), item()]), catalogue);

    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.reason).toContain('même position');
  });

  it('accepte les cibles absentes — une série au poids du corps n’a pas de charge', () => {
    const result = validateProposal(
      proposal([item({ targetWeightKg: null, restSeconds: undefined })]),
      catalogue,
    );

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.proposal.items[0]?.targetWeightKg).toBeNull();
    expect(result.proposal.items[0]?.restSeconds).toBeNull();
  });

  it('arrondit la charge à deux décimales — la colonne est un DECIMAL(6,2)', () => {
    const result = validateProposal(proposal([item({ targetWeightKg: 62.4567 })]), catalogue);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.proposal.items[0]?.targetWeightKg).toBe(62.46);
  });

  it('retombe sur une série normale quand le type est inconnu', () => {
    const result = validateProposal(proposal([item({ kind: 'SUPERSET' })]), catalogue);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.proposal.items[0]?.kind).toBe(WorkoutSetKind.NORMAL);
  });

  it('refuse ce qui n’est pas une proposition', () => {
    expect(validateProposal(null, catalogue).ok).toBe(false);
    expect(validateProposal('séance', catalogue).ok).toBe(false);
    expect(validateProposal({ name: '', estimatedMinutes: 25, items: [] }, catalogue).ok).toBe(
      false,
    );
  });
});
