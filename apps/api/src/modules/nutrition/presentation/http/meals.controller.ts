import { type MealEntry } from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { MealsService } from '../../application/meals.service';
import { CreateMealDto, ListMealsQuery } from './dto/meals.dto';

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
      proteinG: dto.proteinG ?? null,
      eatenAt: dto.eatenAt,
    });
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
