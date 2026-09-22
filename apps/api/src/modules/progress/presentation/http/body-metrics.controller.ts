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
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { BodyMetricsService } from '../../application/body-metrics.service';
import { CreateBodyMetricDto, ListBodyMetricsQuery, UpdateBodyMetricDto } from './dto/progress.dto';

@ApiTags('progress')
@ApiBearerAuth()
@Controller('body-metrics')
export class BodyMetricsController {
  constructor(private readonly metrics: BodyMetricsService) {}

  @Get()
  @ApiOperation({ summary: 'Mesures corporelles (du plus ancien au plus récent)' })
  list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListBodyMetricsQuery,
  ): Promise<BodyMetric[]> {
    return this.metrics.listBodyMetrics(user.userId, query.metricType, query.limit);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Enregistrer une mesure (idempotent — id client)' })
  create(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: CreateBodyMetricDto,
  ): Promise<BodyMetric> {
    return this.metrics.addBodyMetric(user.userId, dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Corriger une mesure (valeur, date, ou les deux)' })
  update(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateBodyMetricDto,
  ): Promise<BodyMetric> {
    return this.metrics.updateBodyMetric(user.userId, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Supprimer une mesure (suppression logique, idempotent)' })
  async remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.metrics.deleteBodyMetric(user.userId, id);
  }
}
