import { decodeXmlEntities, XmlFormatError, xmlRecords } from './xml-records';

const table = (body: string): string =>
  `<?xml version="1.0" encoding="windows-1252"?>\n<TABLE>\n${body}</TABLE>\n`;

describe('xmlRecords', () => {
  it('rend chaque enregistrement en champs texte, espaces de bord ôtées', () => {
    const xml = table(
      '<ALIM>\n<alim_code> 1000 </alim_code>\n<alim_nom_fr> Pastis </alim_nom_fr>\n</ALIM>\n' +
        '<ALIM>\n<alim_code> 1001 </alim_code>\n<alim_nom_fr> Whisky </alim_nom_fr>\n</ALIM>\n',
    );
    expect([...xmlRecords(xml, 'ALIM')]).toEqual([
      { alim_code: '1000', alim_nom_fr: 'Pastis' },
      { alim_code: '1001', alim_nom_fr: 'Whisky' },
    ]);
  });

  it('ne confond pas <ALIM> et <ALIM_GRP>, et range les noms de champ en minuscules', () => {
    const xml = table(
      '<ALIM_GRP><alim_grp_code> 01 </alim_grp_code></ALIM_GRP>' +
        '<ALIM><ALIM_NOM_INDEX_FR> Pastis </ALIM_NOM_INDEX_FR></ALIM>',
    );
    expect([...xmlRecords(xml, 'ALIM')]).toEqual([{ alim_nom_index_fr: 'Pastis' }]);
    expect([...xmlRecords(xml, 'ALIM_GRP')]).toEqual([{ alim_grp_code: '01' }]);
  });

  it('lit les éléments vides à attributs, les entités, et un « < » brut dans un texte', () => {
    const xml = table(
      '<COMPO>\r\n<teneur> &lt; 0,5 </teneur>\r\n<min missing=" " />\r\n' +
        '<brut> < 0,5 </brut>\r\n<nom> Pâtes &amp; riz </nom>\r\n</COMPO>\r\n',
    );
    expect([...xmlRecords(xml, 'COMPO')]).toEqual([
      { teneur: '< 0,5', min: '', brut: '< 0,5', nom: 'Pâtes & riz' },
    ]);
  });

  it('ignore les commentaires, même s’ils contiennent des balises', () => {
    const xml = table(
      '<!-- <ALIM><alim_code> 9 </alim_code></ALIM> -->\n<ALIM><a> 1 </a></ALIM>\n',
    );
    expect([...xmlRecords(xml, 'ALIM')]).toEqual([{ a: '1' }]);
  });

  it('refuse un document tronqué entre deux enregistrements', () => {
    const truncated = '<?xml version="1.0"?>\n<TABLE>\n<ALIM><a> 1 </a></ALIM>\n<ALIM><a> 2';
    expect(() => [...xmlRecords(truncated, 'ALIM')]).toThrow(XmlFormatError);
    const cutBetween = '<?xml version="1.0"?>\n<TABLE>\n<ALIM><a> 1 </a></ALIM>\n';
    expect(() => [...xmlRecords(cutBetween, 'ALIM')]).toThrow(/tronqué/);
  });

  it('refuse un champ jamais fermé ou présent deux fois, en situant l’enregistrement', () => {
    expect(() => [...xmlRecords(table('<ALIM><a> 1 </ALIM>'), 'ALIM')]).toThrow(
      /n° 1 : balise <a> jamais fermée/,
    );
    expect(() => [...xmlRecords(table('<ALIM><a>1</a><a>2</a></ALIM>'), 'ALIM')]).toThrow(
      /apparaît deux fois/,
    );
  });
});

describe('decodeXmlEntities', () => {
  it('décode les entités standard et numériques, laisse les inconnues', () => {
    expect(decodeXmlEntities('&lt;&gt;&amp;&quot;&apos;&#233;&#xE8;&nbsp;')).toBe('<>&"\'éè&nbsp;');
  });
});
