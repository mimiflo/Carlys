import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateMealDto {
  @ApiProperty({ description: 'UUID généré côté client (création idempotente)' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minLength: 1, maxLength: 120 })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @ApiProperty({ minimum: 1, maximum: 10000 })
  @IsInt()
  @Min(1)
  @Max(10_000)
  kcal!: number;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000)
  proteinG?: number;

  @ApiProperty({ description: 'Instant de consommation, UTC (ISO 8601)' })
  @Type(() => Date)
  @IsDate()
  eatenAt!: Date;
}

export class ListMealsQuery {
  @ApiProperty({ description: 'Borne basse (incluse), UTC' })
  @Type(() => Date)
  @IsDate()
  from!: Date;

  @ApiProperty({ description: 'Borne haute (exclue), UTC' })
  @Type(() => Date)
  @IsDate()
  to!: Date;
}
