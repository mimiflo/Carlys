import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

/** La requête d'une page « par curseur » (`cursorPage`) : 50 par défaut, 200 au plus. */
export class CursorPageQuery {
  @ApiPropertyOptional({ description: 'Curseur : id du dernier élément servi' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ default: 50, maximum: 200 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit: number = 50;
}
