import { join } from 'node:path';
import { readCiqualDirectory } from './ciqual-files';
import { type CiqualFood, CiqualParseError, parseCiqual } from './ciqual-parse';

/** Le jeu d'essai au format de la distribution (valeurs ILLUSTRATIVES). */
const FIXTURES = join(__dirname, '..', '..', '..', '..', '..', 'test', 'fixtures', 'ciqual');

function parsedVersion(version: 'v1' | 'v2') {
  return parseCiqual(readCiqualDirectory(join(FIXTURES, version)).xml);
}

function food(foods: readonly CiqualFood[], code: number): CiqualFood {
  const found = foods.find((candidate) => candidate.code === code);
  if (found === undefined) throw new Error(`aliment ${code} absent du jeu d'essai`);
  return found;
}

const xmlTable = (tag: string, records: string): string =>
  `<?xml version="1.0"?>\n<TABLE>\n${records.replace(/\{\}/g, tag)}</TABLE>\n`;

describe('parseCiqual (jeu d’essai au format de la distribution)', () => {
  const v1 = parsedVersion('v1');

  it('importe les aliments dont l’énergie est connue, avec nom court, groupe et clé', () => {
    expect(v1.read).toBe(9);
    expect(v1.foods).toHaveLength(7);
    const poulet = food(v1.foods, 990001);
    expect(poulet).toMatchObject({
      name: 'Poulet, filet, sans peau, cuit',
      shortName: 'Poulet',
      searchKey: 'poulet filet sans peau cuit',
      groupCode: '04',
      groupName: 'viandes, œufs, poissons et assimilés',
      subgroupCode: '0401',
      subgroupName: 'viandes cuites',
    });
    expect(food(v1.foods, 990009).searchKey).toBe('oeuf dur');
  });

  it('lit l’énergie en kcal et les protéines N x Jones, pas leurs voisines', () => {
    const poulet = food(v1.foods, 990001);
    // kJ (630) et N x 6,25 (30,1) sont dans le fichier : ce ne sont pas elles.
    expect(poulet.kcalPer100g.toNumber()).toBe(150);
    expect(poulet.proteinPer100g?.toNumber()).toBe(29);
  });

  it('interprète traces, « < 0,5 » et « - »', () => {
    expect(food(v1.foods, 990001).carbsPer100g?.toNumber()).toBe(0);
    expect(food(v1.foods, 990003).fatPer100g?.toNumber()).toBe(0);
    expect(food(v1.foods, 990006).fatPer100g).toBeNull();
  });

  it('écarte les aliments sans énergie connue, avec leur raison', () => {
    expect(v1.ignored).toEqual([
      { code: 990004, name: 'Eau du robinet', reason: 'énergie inconnue' },
      { code: 990005, name: 'Sel blanc alimentaire, iodé, non fluoré', reason: 'énergie inconnue' },
    ]);
  });

  it('résout les constituants par leur NOM : la v2 les renumérote, les valeurs suivent', () => {
    const v2 = parsedVersion('v2');
    expect(food(v2.foods, 990001).kcalPer100g.toNumber()).toBe(150);
    expect(food(v2.foods, 990003).kcalPer100g.toNumber()).toBe(30.5);
    expect(v2.foods.map((candidate) => candidate.code)).not.toContain(990008);
  });
});

describe('parseCiqual (fichiers défectueux)', () => {
  const { xml } = readCiqualDirectory(join(FIXTURES, 'v1'));

  it('un constituant introuvable fait échouer l’import en le nommant', () => {
    const constants = xml.const.replace('Lipides (g/100 g)', 'Matières grasses (g/100 g)');
    expect(() => parseCiqual({ ...xml, const: constants })).toThrow(CiqualParseError);
    expect(() => parseCiqual({ ...xml, const: constants })).toThrow(/« Lipides \(g\/100 g\) »/);
  });

  it('un constituant présent deux fois fait échouer l’import', () => {
    const doubled = xml.const.replace(
      '</TABLE>',
      '<CONST><const_code> 77 </const_code><const_nom_fr> Glucides (g/100 g) </const_nom_fr></CONST>\n</TABLE>',
    );
    expect(() => parseCiqual({ ...xml, const: doubled })).toThrow(/présent 2 fois/);
  });

  it('une teneur illisible fait échouer l’import en nommant l’aliment', () => {
    const compo = xml.compo.replace('<teneur> 29,0 </teneur>', '<teneur> N.D. </teneur>');
    expect(() => parseCiqual({ ...xml, compo })).toThrow(/aliment 990001.*N\.D\./);
  });

  it('un aliment en double fait échouer l’import', () => {
    const alim = xmlTable(
      'ALIM',
      '<{}><alim_code> 5 </alim_code><alim_nom_fr> A </alim_nom_fr></{}>\n'.repeat(2),
    );
    expect(() => parseCiqual({ ...xml, alim })).toThrow(/l’aliment 5 apparaît deux fois/);
  });
});
