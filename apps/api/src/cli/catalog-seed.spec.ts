import { UsageError, parseArgs } from './catalog-seed';

describe('catalog-seed — arguments', () => {
  it('charge les photos par défaut, les saute sur --sans-photos', () => {
    expect(parseArgs([])).toEqual({ withPhotos: true });
    expect(parseArgs(['--sans-photos'])).toEqual({ withPhotos: false });
  });

  it('refuse une option inconnue', () => {
    expect(() => parseArgs(['--force'])).toThrow(UsageError);
    expect(() => parseArgs(['staging'])).toThrow(/Option inconnue/);
  });
});
