import { type BenchSample, percentile, renderTable, summarize } from './coach-bench.stats';

const ok = (
  firstTokenMs: number,
  totalMs: number,
  maxAhead: number | null = null,
): BenchSample => ({
  outcome: 'ok',
  firstTokenMs,
  totalMs,
  maxAhead,
});

describe('coach-bench : les chiffres remis au propriétaire', () => {
  it('centiles au rang le plus proche', () => {
    expect(percentile([], 50)).toBeNull();
    expect(percentile([3, 1, 2], 50)).toBe(2);
    expect(percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 95)).toBe(10);
    expect(percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 50)).toBe(5);
  });

  it('un palier : issues comptées, débit sur la durée, file la plus longue', () => {
    const report = summarize(
      5,
      [
        ok(1_000, 10_000, null),
        ok(2_000, 20_000, 1),
        ok(3_000, 30_000, 2),
        { outcome: 'busy', firstTokenMs: null, totalMs: 50, maxAhead: null },
        { outcome: 'timeout', firstTokenMs: null, totalMs: 120_000, maxAhead: 3 },
      ],
      60_000,
    );

    expect(report).toMatchObject({
      users: 5,
      ok: 3,
      busy: 1,
      timeouts: 1,
      errors: 0,
      ttftP50Ms: 2_000,
      totalP95Ms: 30_000,
      // 3 attentes devant la demande, plus elle-même.
      maxQueue: 4,
    });
    expect(report.perSecond).toBeCloseTo(0.05);
  });

  it('le tableau a une ligne par palier, en réponses par minute', () => {
    const table = renderTable([summarize(1, [ok(1_500, 12_000)], 12_000)]);
    expect(table.split('\n')).toHaveLength(3);
    expect(table).toContain(
      '| 1 | 1 | 0 | 0 | 0 | 0 | 5.0 | 1.5 s / 1.5 s | 12.0 s / 12.0 s | 0 | 12.0 s |',
    );
  });
});
