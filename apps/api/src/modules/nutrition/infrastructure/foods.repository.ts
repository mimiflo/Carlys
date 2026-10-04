import { Injectable } from '@nestjs/common';
import { type Food, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type ClosestFoodQuery } from '../domain/closest-food-query';

/** Ce que la recherche lit d'un aliment : ni la clé ni les dates. */
export type FoodSearchRow = Pick<
  Food,
  | 'code'
  | 'name'
  | 'shortName'
  | 'groupName'
  | 'kcalPer100g'
  | 'kcalComputed'
  | 'proteinPer100g'
  | 'carbsPer100g'
  | 'fatPer100g'
>;

/** Un mot et ses accords : « cuit », « cuite », « cuits », « cuites ». */
const inflected = (base: string) => `${base}(e|s|x|es)?`;

/** Les colonnes d'un aliment rendu par une recherche (`FoodSearchRow`). */
const SEARCH_COLUMNS = Prisma.sql`"code", "name", "shortName", "groupName",
  "kcalPer100g", "kcalComputed", "proteinPer100g", "carbsPer100g", "fatPer100g"`;

/**
 * Lecture de la base d'aliments. L'écriture n'appartient qu'à l'import
 * CIQUAL (`infrastructure/ciqual/`) : l'API ne crée ni ne modifie jamais un
 * aliment.
 */
@Injectable()
export class FoodsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Chaque mot doit figurer dans la clé de recherche ; les aliments retirés
   * sont exclus. Classement : ceux dont le nom COMMENCE par le premier mot
   * (donc dont le nom court commence par lui), puis les noms les plus
   * courts — « Riz blanc, cuit » avant « Galette de riz soufflé ».
   *
   * Un balayage séquentiel, sans index ni extension (pg_trgm) : la table
   * compte ~3 200 lignes, et `LIKE '%mot%'` n'utiliserait de toute façon pas
   * un index B-tree. Les mots arrivent normalisés (`[a-z0-9]` seulement) :
   * aucun joker SQL ne peut s'y glisser, et la requête reste paramétrée.
   */
  search(words: readonly [string, ...string[]], limit: number): Promise<FoodSearchRow[]> {
    const [first] = words;
    const contains = words.map((word) => Prisma.sql`"searchKey" LIKE ${`%${word}%`}`);
    return this.prisma.$queryRaw<FoodSearchRow[]>`
      SELECT ${SEARCH_COLUMNS} FROM "Food"
      WHERE "retiredAt" IS NULL AND ${Prisma.join(contains, ' AND ')}
      ORDER BY ("searchKey" LIKE ${`${first}%`}) DESC, char_length("name"), "name", "code"
      LIMIT ${limit}`;
  }

  /**
   * L'aliment le plus proche d'un nom libre (`ClosestFoodQuery`), par mots
   * ENTIERS (`\m…\M` : « pois » ne trouve pas « poisson », « oeuf » pas
   * « boeuf »), accordés (`cuit` retrouve « cuites ») : [head] doit figurer
   * dans la clé ; chaque terme ajoute ses points `exact` tel quel, 1 accordé
   * seulement ; `cooked` : « cuit » ajoute 1, « cru » retire 2 ; pas
   * `dried` : séché ou déshydraté, et pas cuit, retire 2. À égalité, celui qui COMMENCE par [head], puis le nom
   * le plus court, « (aliment moyen) » non compté : l'aliment moyen est le
   * bon défaut quand la photo ne dit pas la variante. Les mots arrivent
   * normalisés (`[a-z0-9]`) : rien ne s'injecte dans le motif, paramétré.
   */
  async closest(
    head: string,
    { terms, cooked, dried }: Pick<ClosestFoodQuery, 'terms' | 'cooked' | 'dried'>,
  ): Promise<FoodSearchRow | null> {
    const has = (pattern: string) => Prisma.sql`"searchKey" ~ ${`\\m${pattern}\\M`}`;
    const points = [
      Prisma.sql`0`,
      ...terms.map(
        ({ word, base, exact }) =>
          Prisma.sql`(CASE WHEN ${has(word)} THEN ${exact} WHEN ${has(inflected(base))} THEN 1 ELSE 0 END)`,
      ),
      ...(cooked
        ? [
            Prisma.sql`(CASE WHEN ${has(inflected('cuit'))} THEN 1 ELSE 0 END)`,
            Prisma.sql`(CASE WHEN ${has(inflected('cru'))} THEN -2 ELSE 0 END)`,
          ]
        : []),
      ...(dried
        ? []
        : [
            // Séché ET pas cuit : « Pâtes sèches, cuites » n'est pas la pomme sèche.
            Prisma.sql`(CASE WHEN ${has('(sec|seche|deshydrate)(e|s|x|es)?')}
              AND NOT ${has(inflected('cuit'))} THEN -2 ELSE 0 END)`,
          ]),
    ];
    const [row] = await this.prisma.$queryRaw<FoodSearchRow[]>`
      SELECT ${SEARCH_COLUMNS} FROM "Food"
      WHERE "retiredAt" IS NULL AND ${has(inflected(head))}
      ORDER BY (${Prisma.join(points, ' + ')}) DESC, ("searchKey" ~ ${`^${head}`}) DESC,
               char_length(replace("name", ' (aliment moyen)', '')), "name", "code"
      LIMIT 1`;
    return row ?? null;
  }

  findByCode(code: number): Promise<Food | null> {
    return this.prisma.food.findUnique({ where: { code } });
  }

  /** Retirés compris : c'est à l'appelant de dire pourquoi il les refuse. */
  findByCodes(codes: readonly number[]): Promise<Food[]> {
    return this.prisma.food.findMany({ where: { code: { in: [...codes] } } });
  }

  /**
   * La version de la table en service. Après un import complet, tous les
   * aliments actifs portent la même : n'importe lequel la dit.
   */
  async currentVersion(): Promise<string | null> {
    const food = await this.prisma.food.findFirst({
      where: { retiredAt: null },
      select: { sourceVersion: true },
      orderBy: { updatedAt: 'desc' },
    });
    return food?.sourceVersion ?? null;
  }
}
