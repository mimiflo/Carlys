import { normalizeBarcode } from './barcode';

describe('normalizeBarcode', () => {
  it('rend un EAN-13, un EAN-8 ou un UPC-A dont le contrôle tombe juste', () => {
    expect(normalizeBarcode('3017620422003')).toBe('3017620422003'); // pâte à tartiner
    expect(normalizeBarcode(' 96385074 ')).toBe('96385074'); // EAN-8
    expect(normalizeBarcode('036000291452')).toBe('036000291452'); // UPC-A
  });

  it('refuse un chiffre faux : la lecture ratée ne cherche pas le produit d’un autre', () => {
    expect(normalizeBarcode('3017620422004')).toBeNull();
  });

  it('refuse ce qui n’est pas un code de produit', () => {
    for (const raw of ['', 'abc', '12345', '30176204220031234', '3017620422003; DROP']) {
      expect(normalizeBarcode(raw)).toBeNull();
    }
  });
});
