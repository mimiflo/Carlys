import { type BodyMetric } from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { ProgressService } from '../../application/progress.service';
import { CreateBodyMetricDto, ListBodyMetricsQuery } from './dto/progress.dto';

@ApiTags('progress')
@ApiBearerAuth()
@Controller('body-metrics')
export class BodyMetricsController {
  constructor(private readonly progress: ProgressService) {}

  @Get()
  @ApiOperation({ summary: 'Mesures corporelles (du plus ancien au plus récent)' })
  list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListBodyMetricsQuery,
  ): Promise<BodyMetric[]> {
    return this.progress.listBodyMetrics(user.userId, query.metricType, query.limit);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Enregistrer une mesure (idempotent — id client)' })
  create(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: CreateBodyMetricDto,
  ): Promise<BodyMetric> {
    return this.progress.addBodyMetric(user.userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Supprimer une mesure (suppression logique, idempotent)' })
  async remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.progress.deleteBodyMetric(user.userId, id);
  }
}
