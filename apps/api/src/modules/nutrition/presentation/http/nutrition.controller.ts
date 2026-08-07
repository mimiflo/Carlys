import { type MetabolismReport } from '@carlys/api-contracts';
import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { NutritionService } from '../../application/nutrition.service';

@ApiTags('nutrition')
@ApiBearerAuth()
@Controller('nutrition')
export class NutritionController {
  constructor(private readonly nutrition: NutritionService) {}

  @Get('metabolism')
  @ApiOperation({
    summary: 'Rapport métabolique (BMR, TDEE, objectif calorique, macros, IMC, hydratation)',
  })
  metabolism(@CurrentUser() user: AuthenticatedPrincipal): Promise<MetabolismReport> {
    return this.nutrition.metabolismReport(user.userId);
  }
}
