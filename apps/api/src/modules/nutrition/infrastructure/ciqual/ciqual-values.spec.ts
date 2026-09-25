import { parseTeneur, TeneurFormatError } from './ciqual-values';

const value = (raw: string): number | null => parseTeneur(raw)?.toNumber() ?? null;

describe('parseTeneur', () => {
  it('lit une valeur à virgule décimale (et à point, par tolérance)', () => {
    expect(value(' 12,5 ')).toBe(12.5);
    expect(value('1080')).toBe(1080);
    expect(value('0.3')).toBe(0.3);
  });

  it('garde deux décimales, comme la colonne qui la reçoit', () => {
    expect(value('0,125')).toBe(0.13);
    expect(value('0,0049')).toBe(0);
  });

  it('« traces » vaut 0 : présent, en quantité négligeable', () => {
    expect(value('traces')).toBe(0);
    expect(value('Traces')).toBe(0);
  });

  it('« < x » vaut 0 : sous le seuil de quantification du dosage', () => {
    expect(value('< 0,5')).toBe(0);
    expect(value('<0,05')).toBe(0);
    expect(value('<\u00a01')).toBe(0);
  });

  it('« - » ou vide vaut null : non dosé, JAMAIS zéro', () => {
    expect(parseTeneur('-')).toBeNull();
    expect(parseTeneur('')).toBeNull();
    expect(parseTeneur('   ')).toBeNull();
  });

  it('refuse toute autre forme en la citant : une convention nouvelle ne se devine pas', () => {
    expect(() => parseTeneur('N.D.')).toThrow(TeneurFormatError);
    expect(() => parseTeneur('1,5 g')).toThrow(/« 1,5 g »/);
    expect(() => parseTeneur('-3')).toThrow(TeneurFormatError);
  });
});
