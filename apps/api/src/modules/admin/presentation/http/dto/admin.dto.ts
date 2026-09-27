import {
  ENTITLEMENT_KEYS,
  type EntitlementKey,
  MANUAL_ENTITLEMENT_REASON_MAX,
} from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { trimmed } from '../../../../../common/transforms/trimmed';
import {
  IsBoolean,
  IsDate,
  IsEmail,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class AdminLoginDto {
  @ApiProperty({ example: 'dev.admin@carlys.local' })
  @IsEmail()
  email!: string;

  @ApiProperty()
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password!: string;
}

/**
 * POST /admin/users/search — un CORPS, et non une query string : la
 * recherche porte souvent une adresse e-mail, et une URL finit dans le
 * journal d'accès Nginx, dans celui de Pino (`req.url`) et dans
 * l'historique du navigateur.
 */
export class SearchManagedUsersDto {
  @ApiPropertyOptional({ description: 'Recherche sur e-mail ou nom affiché' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @ApiPropertyOptional({ description: 'Curseur : id du dernier élément servi' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  /**
   * Ni `@IsOptional` ni `@Type` : absent, il garde sa valeur par défaut ;
   * présent, c'est un entier, jamais `"20"`, `true` ou `null` (un corps JSON
   * porte déjà des nombres, et `null` servait une page vide).
   */
  @ApiPropertyOptional({ default: 20, maximum: 100 })
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;
}

export class ListAdminExercisesQuery {
  @ApiPropertyOptional({ description: 'Recherche sur le nom ou le slug' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @ApiPropertyOptional({
    default: false,
    description: 'Inclure les exercices supprimés — la seule façon de les restaurer',
  })
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  includeDeleted: boolean = false;

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

export class SetUserStatusDto {
  @ApiProperty({ enum: ['ACTIVE', 'SUSPENDED'] })
  @IsIn(['ACTIVE', 'SUSPENDED'])
  status!: 'ACTIVE' | 'SUSPENDED';
}

export class SetEntitlementDto {
  @ApiProperty({ enum: ENTITLEMENT_KEYS })
  @IsIn(ENTITLEMENT_KEYS)
  key!: EntitlementKey;

  @ApiProperty()
  @IsBoolean()
  isActive!: boolean;

  @ApiPropertyOptional({ description: 'Expiration UTC ; absent = sans expiration' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  expiresAt?: Date;

  @ApiPropertyOptional({
    description:
      'Raison de la décision, journalisée dans l’audit : facultative pour offrir, OBLIGATOIRE pour couper (`isActive: false`)',
    maxLength: MANUAL_ENTITLEMENT_REASON_MAX,
  })
  // Une coupure prive un membre d'un accès parfois payé : sans raison, elle
  // est refusée, quel que soit le client (contrat `managedEntitlementDecisionSchema`).
  @ValidateIf((dto: SetEntitlementDto) => dto.isActive === false || dto.reason !== undefined)
  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxLength(MANUAL_ENTITLEMENT_REASON_MAX)
  reason?: string;
}

/** DELETE /admin/users/:id/entitlements/:key — le compte et le droit à relâcher. */
export class ManagedEntitlementParams {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  id!: string;

  @ApiProperty({ enum: ENTITLEMENT_KEYS })
  @IsIn(ENTITLEMENT_KEYS)
  key!: EntitlementKey;
}

export class ListAuditLogsQuery {
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

export class SetPublicationDto {
  @ApiProperty()
  @IsBoolean()
  isPublished!: boolean;
}
