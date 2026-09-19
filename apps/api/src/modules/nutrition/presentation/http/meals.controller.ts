import { type MealEntry } from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { MealsService } from '../../application/meals.service';
import { CreateMealDto, ListMealsQuery, UpdateMealDto } from './dto/meals.dto';

@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition/meals')
export class MealsController {
  constructor(private readonly meals: MealsService) {}

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: 'Ajouter un repas (id client, création idempotente)' })
  add(@CurrentUser() user: AuthenticatedPrincipal, @Body() dto: CreateMealDto): Promise<MealEntry> {
    return this.meals.add(user.userId, {
      id: dto.id,
      name: dto.name,
      kcal: dto.kcal,
      quantity: dto.quantity ?? null,
      quantityUnit: dto.quantityUnit ?? null,
      proteinG: dto.proteinG ?? null,
      carbsG: dto.carbsG ?? null,
      fatG: dto.fatG ?? null,
      eatenAt: dto.eatenAt,
    });
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Corriger un repas — un champ absent reste tel quel, un champ à null ' +
      'efface ce qu’on croyait savoir',
  })
  update(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateMealDto,
  ): Promise<MealEntry> {
    // Le DTO est recopié tel quel : `undefined` (« n'y touche pas ») et
    // `null` (« efface ») doivent traverser sans être confondus, ce qu'un
    // `?? null` ferait exactement.
    return this.meals.update(user.userId, id, dto);
  }

  @Get()
  @ApiOperation({
    summary:
      'Repas entre deux instants UTC — le client envoie les bornes de SA ' +
      'journée locale, le serveur ne devine jamais le fuseau',
  })
  list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListMealsQuery,
  ): Promise<MealEntry[]> {
    return this.meals.list(user.userId, query.from, query.to);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Retirer un repas (suppression douce, idempotente)' })
  remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    return this.meals.remove(user.userId, id);
  }
}
