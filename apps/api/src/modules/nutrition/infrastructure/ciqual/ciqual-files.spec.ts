import { CiqualFilesError, decodeCiqualXml, locateCiqualFiles } from './ciqual-files';

const DISTRIBUTION = [
  'alim_2020_07_07.xml',
  'alim_grp_2020_07_07.xml',
  'compo_2020_07_07.xml',
  'const_2020_07_07.xml',
  'sources_2020_07_07.xml',
  'LISEZMOI.pdf',
];

describe('locateCiqualFiles', () => {
  it('reconnaît les quatre fichiers, sans que alim_ avale alim_grp_, et date la version', () => {
    const set = locateCiqualFiles(DISTRIBUTION);
    expect(set.files).toEqual({
      alim: 'alim_2020_07_07.xml',
      alimGrp: 'alim_grp_2020_07_07.xml',
      compo: 'compo_2020_07_07.xml',
      const: 'const_2020_07_07.xml',
    });
    expect(set.datedVersion).toBe('2020-07-07');
    expect(set.warnings).toEqual([]);
  });

  it('échoue en nommant CHAQUE fichier manquant', () => {
    expect(() => locateCiqualFiles(['alim_2020_07_07.xml', 'compo_2020_07_07.xml'])).toThrow(
      /alim_grp_\*\.xml.*const_\*\.xml/,
    );
    expect(() => locateCiqualFiles([])).toThrow(CiqualFilesError);
  });

  it('refuse deux versions mélangées plutôt que d’en choisir une au hasard', () => {
    expect(() => locateCiqualFiles([...DISTRIBUTION, 'compo_2017_11_21.xml'])).toThrow(
      /plusieurs fichiers compo_\*\.xml/,
    );
  });

  it('signale des dates discordantes sans bloquer, et garde un suffixe non daté tel quel', () => {
    const set = locateCiqualFiles([
      'alim_2020_07_07.xml',
      'alim_grp_2020_07_07.xml',
      'compo_2020_07_08.xml',
      'const_2020_07_07.xml',
    ]);
    expect(set.warnings).toEqual([expect.stringContaining('compo_2020_07_08.xml') as unknown]);
    const undated = locateCiqualFiles([
      'alim_x.xml',
      'alim_grp_x.xml',
      'compo_x.xml',
      'const_x.xml',
    ]);
    expect(undated.datedVersion).toBe('x');
  });
});

describe('decodeCiqualXml', () => {
  it('lit le windows-1252 de la distribution : « è », « ° » et « œ » (0x9C)', () => {
    const bytes = Buffer.concat([
      Buffer.from('<?xml version="1.0" encoding="windows-1252"?><a>R'),
      Buffer.from([0xe8]),
      Buffer.from('glement N'),
      Buffer.from([0xb0]),
      Buffer.from(' '),
      Buffer.from([0x9c]),
      Buffer.from('uf</a>'),
    ]);
    expect(decodeCiqualXml(bytes)).toContain('Règlement N° œuf');
  });

  it('suit l’encodage déclaré, et windows-1252 à défaut de déclaration', () => {
    expect(
      decodeCiqualXml(Buffer.from('<?xml version="1.0" encoding="UTF-8"?><a>é</a>')),
    ).toContain('é');
    expect(decodeCiqualXml(Buffer.from([0x3c, 0x61, 0x3e, 0xe9, 0x3c, 0x2f, 0x61, 0x3e]))).toBe(
      '<a>é</a>',
    );
  });

  it('refuse un UTF-8 invalide ou un encodage inconnu, au lieu de lire des caractères de remplacement', () => {
    const invalid = Buffer.concat([
      Buffer.from('<?xml version="1.0" encoding="utf-8"?><a>'),
      Buffer.from([0xe8]),
      Buffer.from('</a>'),
    ]);
    expect(() => decodeCiqualXml(invalid)).toThrow(CiqualFilesError);
    expect(() =>
      decodeCiqualXml(Buffer.from('<?xml version="1.0" encoding="klingon"?><a/>')),
    ).toThrow(/klingon/);
  });
});
