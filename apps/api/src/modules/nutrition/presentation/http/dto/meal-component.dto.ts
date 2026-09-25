import {
  MEAL_COMPONENT_QUANTITY_G_MAX,
  MEAL_COMPONENT_QUANTITY_G_MIN,
} from '@carlys/api-contracts';
import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsNumber, IsUUID, Max, Min } from 'class-validator';
import { FOOD_CODE_MAX } from '../../../domain/meal-bounds';

/**
 * Une ligne d'une composition, telle que le client l'envoie : LAQUELLE (son
 * identifiant), QUOI (le code de la base) et COMBIEN (en grammes). Rien
 * d'autre : le nom, le groupe et les valeurs nutritionnelles, le serveur les
 * lit dans la base au moment de l'ajout et en garde l'instantané.
 */
export class MealComponentInputDto {
  @ApiProperty({
    format: 'uuid',
    description:
      'UUID généré sur l’appareil à l’ajout de la ligne, puis conservé. En correction, un id ' +
      'déjà présent dans le repas GARDE l’instantané de sa ligne (nom, valeurs, version de la ' +
      'table) et n’en change que la quantité et la place ; un id neuf lit la base. Changer ' +
      'd’aliment, c’est une ligne neuve (400 sinon). Unique dans tout le journal (409 sinon).',
  })
  @IsUUID()
  id!: string;

  @ApiProperty({
    type: 'integer',
    description: 'Code de l’aliment dans la base (`code` de GET /nutrition/foods)',
    minimum: 1,
  })
  @IsInt()
  @Min(1)
  @Max(FOOD_CODE_MAX)
  foodCode!: number;

  @ApiProperty({
    description: 'Quantité mangée de cet aliment, en grammes (deux décimales)',
    minimum: MEAL_COMPONENT_QUANTITY_G_MIN,
    maximum: MEAL_COMPONENT_QUANTITY_G_MAX,
    example: 120,
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(MEAL_COMPONENT_QUANTITY_G_MIN)
  @Max(MEAL_COMPONENT_QUANTITY_G_MAX)
  quantityG!: number;
}
