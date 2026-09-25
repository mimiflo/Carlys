import { Injectable } from '@nestjs/common';
import { type Food, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Ce que la recherche lit d'un aliment : ni la clé ni les dates. */
export type FoodSearchRow = Pick<
  Food,
  | 'code'
  | 'name'
  | 'shortName'
  | 'groupName'
  | 'kcalPer100g'
  | 'proteinPer100g'
  | 'carbsPer100g'
  | 'fatPer100g'
>;

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
      SELECT "code", "name", "shortName", "groupName",
             "kcalPer100g", "proteinPer100g", "carbsPer100g", "fatPer100g"
      FROM "Food"
      WHERE "retiredAt" IS NULL AND ${Prisma.join(contains, ' AND ')}
      ORDER BY ("searchKey" LIKE ${`${first}%`}) DESC, char_length("name"), "name", "code"
      LIMIT ${limit}`;
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
