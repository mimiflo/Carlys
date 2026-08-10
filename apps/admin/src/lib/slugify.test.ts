import { describe, expect, it } from 'vitest';
import { slugify } from '@/app/categories/page';

describe('slugify', () => {
  it('retire les accents et sépare les mots par des tirets', () => {
    expect(slugify('Trapèzes')).toBe('trapezes');
    expect(slugify('Ischio-jambiers')).toBe('ischio-jambiers');
    expect(slugify('Avant   bras')).toBe('avant-bras');
    expect(slugify('Épaules ')).toBe('epaules');
  });

  it('ne laisse jamais de tiret en tête ni en queue', () => {
    // Un slug bordé de tirets serait refusé par le serveur, et le message
    // d'erreur arriverait après coup — autant proposer un slug valide.
    expect(slugify('  — Dos —  ')).toBe('dos');
    expect(slugify('!!!')).toBe('');
  });
});
