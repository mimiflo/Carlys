import { Module } from '@nestjs/common';
import { ProgressService } from './application/progress.service';
import { ProgressRepository } from './infrastructure/progress.repository';
import { BodyMetricsController } from './presentation/http/body-metrics.controller';
import { ProgressController } from './presentation/http/progress.controller';

@Module({
  controllers: [ProgressController, BodyMetricsController],
  providers: [ProgressService, ProgressRepository],
  exports: [ProgressService],
})
export class ProgressModule {}
