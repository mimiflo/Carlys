/**
 * Les bornes d'un REPAS, en un seul endroit.
 *
 * Le DTO les applique à ce que la personne saisit ; la composition les
 * applique à ce que le serveur calcule. Un repas composé qui les dépasse
 * est aussi absurde qu'un repas saisi qui les dépasse — et une somme de
 * grammes au-delà de `MEAL_QUANTITY_MAX` ne tiendrait même pas dans la
 * colonne (`Decimal(7, 2)`) : Postgres répondrait par un 500.
 */
export const MEAL_KCAL_MIN = 1;
export const MEAL_KCAL_MAX = 10_000;
export const MEAL_MACRO_MAX_G = 1_000;
export const MEAL_QUANTITY_MIN = 0.01;
export const MEAL_QUANTITY_MAX = 9_999.99;

/**
 * Le plus grand code d'aliment que la colonne `Food.code` (`Int`
 * PostgreSQL) peut porter. Au-delà, Prisma lèverait une erreur de
 * validation, servie en 500, pour ce qui n'est qu'un code inconnu.
 */
export const FOOD_CODE_MAX = 2_147_483_647;
