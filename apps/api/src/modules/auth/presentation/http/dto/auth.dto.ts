import {
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  SOCIAL_ID_TOKEN_MAX_LENGTH,
  type SocialProvider,
} from '@carlys/api-contracts';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  MinLength,
} from 'class-validator';

export class DeviceInfoDto {
  @ApiPropertyOptional({ example: 'iPhone de Camille' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceName?: string;

  @ApiPropertyOptional({ example: 'ios' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  devicePlatform?: string;
}

export class RegisterDto extends DeviceInfoDto {
  @ApiProperty({ example: 'camille@example.com' })
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email!: string;

  @ApiProperty({ minLength: PASSWORD_MIN_LENGTH, maxLength: PASSWORD_MAX_LENGTH })
  @IsString()
  @MinLength(PASSWORD_MIN_LENGTH, {
    message: `Le mot de passe doit contenir au moins ${PASSWORD_MIN_LENGTH} caractères.`,
  })
  @MaxLength(PASSWORD_MAX_LENGTH)
  password!: string;

  @ApiProperty({ example: 'Camille' })
  @IsString()
  @Length(1, 60)
  displayName!: string;
}

export class LoginDto extends DeviceInfoDto {
  @ApiProperty({ example: 'camille@example.com' })
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email!: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(PASSWORD_MAX_LENGTH)
  password!: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  refreshToken!: string;
}

export class VerifyEmailDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  token!: string;
}

export class ForgotPasswordDto {
  @ApiProperty({ example: 'camille@example.com' })
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email!: string;
}

export class ResetPasswordDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  token!: string;

  @ApiProperty({ minLength: PASSWORD_MIN_LENGTH, maxLength: PASSWORD_MAX_LENGTH })
  @IsString()
  @MinLength(PASSWORD_MIN_LENGTH, {
    message: `Le mot de passe doit contenir au moins ${PASSWORD_MIN_LENGTH} caractères.`,
  })
  @MaxLength(PASSWORD_MAX_LENGTH)
  newPassword!: string;
}

export class SocialLoginDto extends DeviceInfoDto {
  @ApiProperty({ enum: ['apple', 'google'] })
  @IsIn(['apple', 'google'], { message: 'Fournisseur inconnu.' })
  provider!: SocialProvider;

  /** Jeton d'IDENTITÉ (JWT) du fournisseur — jamais un access token. */
  @ApiProperty({ description: "Jeton d'identité émis par Apple ou Google." })
  @IsString()
  @IsNotEmpty()
  @MaxLength(SOCIAL_ID_TOKEN_MAX_LENGTH)
  idToken!: string;

  /** Apple ne transmet le nom qu'à la PREMIÈRE connexion, hors jeton. */
  @ApiPropertyOptional({ example: 'Camille' })
  @IsOptional()
  @IsString()
  @Length(1, 60)
  displayName?: string;
}

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(PASSWORD_MAX_LENGTH)
  currentPassword!: string;

  @ApiProperty({ minLength: PASSWORD_MIN_LENGTH, maxLength: PASSWORD_MAX_LENGTH })
  @IsString()
  @MinLength(PASSWORD_MIN_LENGTH, {
    message: `Le mot de passe doit contenir au moins ${PASSWORD_MIN_LENGTH} caractères.`,
  })
  @MaxLength(PASSWORD_MAX_LENGTH)
  newPassword!: string;
}
