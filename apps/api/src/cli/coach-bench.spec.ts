import { parseBenchArgs } from './coach-bench';

describe('coach-bench : ses options', () => {
  it('par défaut : les six paliers demandés, sur l’API locale', () => {
    expect(parseBenchArgs([])).toMatchObject({
      url: 'http://localhost:3000',
      levels: [1, 5, 10, 25, 50, 100],
      keep: false,
      confirm: false,
    });
  });

  it('paliers, adresse et confirmation explicites', () => {
    expect(
      parseBenchArgs(['--levels', '1,3', '--url', 'http://api:3000/', '--confirm']),
    ).toMatchObject({ url: 'http://api:3000', levels: [1, 3], confirm: true });
  });

  it('des paliers illisibles sont refusés plutôt qu’ignorés', () => {
    expect(() => parseBenchArgs(['--levels', 'beaucoup'])).toThrow('--levels');
  });

  it('pas plus de 100 par palier : au-delà, la limite par IP fausserait la mesure', () => {
    expect(parseBenchArgs(['--levels', '50,100,200']).levels).toEqual([50, 100]);
    expect(() => parseBenchArgs(['--levels', '500'])).toThrow('de 1 à 100');
  });
});
