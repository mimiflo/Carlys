import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

export const FOOD_SEARCH_DEFAULT_LIMIT = 20;
const FOOD_SEARCH_MAX_LIMIT = 30;

/**
 * `GET /nutrition/foods?q=&limit=`.
 *
 * Deux caractères au moins : une lettre seule rendrait la moitié de la table
 * à chaque frappe. Soixante au plus : aucun nom d'aliment CIQUAL n'a besoin
 * de plus pour être retrouvé, et la borne tient la requête courte.
 */
export class SearchFoodsQuery {
  @ApiProperty({
    minLength: 2,
    maxLength: 60,
    description:
      'Mots cherchés dans le nom (tous doivent y être), sans égard à la casse, ' +
      'aux accents ni aux ligatures : « oeuf » trouve « Œuf ».',
    example: 'poulet cuit',
  })
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  q!: string;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 1,
    maximum: FOOD_SEARCH_MAX_LIMIT,
    default: FOOD_SEARCH_DEFAULT_LIMIT,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(FOOD_SEARCH_MAX_LIMIT)
  limit?: number;
}
