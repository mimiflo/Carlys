import { type Prisma } from '@prisma/client';
import { normalizeFoodText, shortFoodName } from '../../domain/food-text';
import { parseTeneur } from './ciqual-values';
import { xmlRecords } from './xml-records';

/**
 * De la distribution XML décodée aux aliments à importer.
 *
 * Les constituants se résolvent PAR LEUR NOM dans `const_*.xml`, jamais par
 * un code numérique supposé : les codes sont un détail de la distribution,
 * le nom est ce que l'Anses publie et documente. Un constituant introuvable
 * — ou trouvé deux fois — fait échouer l'import en le nommant.
 */

export class CiqualParseError extends Error {}

/** Les quatre constituants lus, sous leur nom officiel. */
export const CIQUAL_CONSTITUENTS = {
  kcal: 'Energie, Règlement UE N° 1169/2011 (kcal/100 g)',
  protein: 'Protéines, N x facteur de Jones (g/100 g)',
  carbs: 'Glucides (g/100 g)',
  fat: 'Lipides (g/100 g)',
} as const;
type Constituent = keyof typeof CIQUAL_CONSTITUENTS;

export interface CiqualFood {
  readonly code: number;
  readonly name: string;
  readonly shortName: string;
  readonly searchKey: string;
  readonly groupCode: string | null;
  readonly groupName: string | null;
  readonly subgroupCode: string | null;
  readonly subgroupName: string | null;
  readonly kcalPer100g: Prisma.Decimal;
  readonly proteinPer100g: Prisma.Decimal | null;
  readonly carbsPer100g: Prisma.Decimal | null;
  readonly fatPer100g: Prisma.Decimal | null;
}

export type IgnoredReason = 'énergie inconnue' | 'nom absent';

export interface CiqualIgnored {
  readonly code: number;
  readonly name: string;
  readonly reason: IgnoredReason;
}

export interface ParsedCiqual {
  readonly foods: readonly CiqualFood[];
  readonly ignored: readonly CiqualIgnored[];
  /** Enregistrements de `alim_*.xml` lus, importés ou non. */
  readonly read: number;
}

/**
 * La clé de comparaison d'un nom de constituant : insensible à la casse, aux
 * accents et aux espaces doublées (« fibres  (kcal » existe dans la table).
 * « Nº » (indicateur ordinal) et « N° » (degré) se valent : les deux se
 * rencontrent sous la même plume.
 */
function constituentKey(name: string): string {
  return normalizeFoodText(name.replace(/º/g, '°'));
}

/** Une valeur absente de la table (« - », vide) vaut `null`. */
function textOrNull(value: string | undefined): string | null {
  const text = value?.trim() ?? '';
  return text === '' || text === '-' ? null : text;
}

function resolveConstituents(constXml: string): Record<Constituent, string> {
  const wanted = Object.entries(CIQUAL_CONSTITUENTS) as [Constituent, string][];
  const found = new Map<Constituent, string[]>();
  for (const record of xmlRecords(constXml, 'CONST')) {
    const key = constituentKey(record.const_nom_fr ?? '');
    for (const [constituent, name] of wanted) {
      if (key === constituentKey(name) && record.const_code !== undefined) {
        found.set(constituent, [...(found.get(constituent) ?? []), record.const_code]);
      }
    }
  }
  const codes = {} as Record<Constituent, string>;
  const problems: string[] = [];
  for (const [constituent, name] of wanted) {
    const matches = found.get(constituent) ?? [];
    const [only] = matches;
    if (matches.length === 1 && only !== undefined) {
      codes[constituent] = only;
    } else {
      problems.push(
        matches.length === 0
          ? `constituant introuvable dans const_*.xml : « ${name} »`
          : `constituant « ${name} » présent ${matches.length} fois (codes ${matches.join(', ')})`,
      );
    }
  }
  if (problems.length > 0) {
    throw new CiqualParseError(problems.join(' ; ') + '.');
  }
  return codes;
}

function groupNames(groupXml: string): {
  groups: Map<string, string>;
  subgroups: Map<string, string>;
} {
  const groups = new Map<string, string>();
  const subgroups = new Map<string, string>();
  for (const record of xmlRecords(groupXml, 'ALIM_GRP')) {
    const groupCode = textOrNull(record.alim_grp_code);
    const groupName = textOrNull(record.alim_grp_nom_fr);
    if (groupCode !== null && groupName !== null) groups.set(groupCode, groupName);
    const subgroupCode = textOrNull(record.alim_ssgrp_code);
    const subgroupName = textOrNull(record.alim_ssgrp_nom_fr);
    if (subgroupCode !== null && subgroupName !== null) subgroups.set(subgroupCode, subgroupName);
  }
  return { groups, subgroups };
}

type Values = Partial<Record<Constituent, Prisma.Decimal | null>>;

function alimCode(raw: string | undefined, where: string): number {
  const text = raw?.trim() ?? '';
  if (!/^\d{1,9}$/.test(text)) {
    throw new CiqualParseError(`${where} : alim_code illisible « ${text} ».`);
  }
  return Number(text);
}

/** Les teneurs des quatre constituants, par aliment. */
function compositions(compoXml: string, codes: Record<Constituent, string>): Map<number, Values> {
  const byConstCode = new Map<string, Constituent>(
    (Object.entries(codes) as [Constituent, string][]).map(([constituent, code]) => [
      code,
      constituent,
    ]),
  );
  const values = new Map<number, Values>();
  for (const record of xmlRecords(compoXml, 'COMPO')) {
    const constituent = byConstCode.get(record.const_code?.trim() ?? '');
    if (constituent === undefined) continue;
    const code = alimCode(record.alim_code, 'compo_*.xml');
    const entry = values.get(code) ?? {};
    if (constituent in entry) {
      throw new CiqualParseError(
        `compo_*.xml : deux teneurs « ${CIQUAL_CONSTITUENTS[constituent]} » pour l’aliment ${code}.`,
      );
    }
    try {
      entry[constituent] = parseTeneur(record.teneur ?? '');
    } catch (error) {
      throw new CiqualParseError(
        `compo_*.xml, aliment ${code}, « ${CIQUAL_CONSTITUENTS[constituent]} » : ${(error as Error).message}`,
      );
    }
    values.set(code, entry);
  }
  return values;
}

/** Assemble les aliments importables et la liste des ignorés, avec leur raison. */
export function parseCiqual(xml: {
  readonly alim: string;
  readonly alimGrp: string;
  readonly compo: string;
  readonly const: string;
}): ParsedCiqual {
  const codes = resolveConstituents(xml.const);
  const { groups, subgroups } = groupNames(xml.alimGrp);
  const values = compositions(xml.compo, codes);
  const foods: CiqualFood[] = [];
  const ignored: CiqualIgnored[] = [];
  const seen = new Set<number>();
  for (const record of xmlRecords(xml.alim, 'ALIM')) {
    const code = alimCode(record.alim_code, 'alim_*.xml');
    if (seen.has(code)) {
      throw new CiqualParseError(`alim_*.xml : l’aliment ${code} apparaît deux fois.`);
    }
    seen.add(code);
    const name = (record.alim_nom_fr ?? '').replace(/\s+/g, ' ').trim();
    const food = values.get(code) ?? {};
    const kcal = food.kcal ?? null;
    if (name === '' || kcal === null) {
      ignored.push({ code, name, reason: name === '' ? 'nom absent' : 'énergie inconnue' });
      continue;
    }
    const groupCode = textOrNull(record.alim_grp_code);
    const subgroupCode = textOrNull(record.alim_ssgrp_code);
    foods.push({
      code,
      name,
      shortName: shortFoodName(name),
      searchKey: normalizeFoodText(name),
      groupCode,
      groupName: groupCode === null ? null : (groups.get(groupCode) ?? null),
      subgroupCode,
      subgroupName: subgroupCode === null ? null : (subgroups.get(subgroupCode) ?? null),
      kcalPer100g: kcal,
      proteinPer100g: food.protein ?? null,
      carbsPer100g: food.carbs ?? null,
      fatPer100g: food.fat ?? null,
    });
  }
  return { foods, ignored, read: seen.size };
}
