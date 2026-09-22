import { Module } from '@nestjs/common';
import { BodyMetricsService } from './application/body-metrics.service';
import { ProgressService } from './application/progress.service';
import { TimelineService } from './application/timeline.service';
import { ProgressRepository } from './infrastructure/progress.repository';
import { BodyMetricsController } from './presentation/http/body-metrics.controller';
import { ProgressController } from './presentation/http/progress.controller';

@Module({
  controllers: [ProgressController, BodyMetricsController],
  providers: [ProgressService, BodyMetricsService, TimelineService, ProgressRepository],
  exports: [ProgressService, BodyMetricsService],
})
export class ProgressModule {}
