import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class SessionResultDto {
  @IsInt() @Min(0) @Max(6) exerciseId!: number;
  @IsInt() @Min(0) setsDone!: number;
  @IsInt() @Min(0) repsDone!: number;
}

export class SessionEventDto {
  @IsInt() @Min(0) seq!: number;
  @IsInt() @Min(1) @Max(3) type!: number;
  @IsInt() @Min(0) @Max(6) exerciseId!: number;
  @IsInt() @Min(0) repIndex!: number;
  @IsInt() @Min(0) @Max(255) confidence!: number;
  @IsInt() @Min(0) deviceTimestampMs!: number;
}

export class CreateSessionDto {
  /** UUID generado por la app: si la subida se reintenta, no se duplica. */
  @IsString() @MaxLength(64) clientSessionId!: string;
  @IsString() prescriptionId!: string;
  @IsIn(['VERIFIED', 'REPORTED']) source!: 'VERIFIED' | 'REPORTED';
  @IsOptional() @IsString() deviceBleName?: string;
  @IsOptional() @IsInt() fwVersion?: number;
  @IsOptional() @IsInt() modelVersion?: number;
  @IsOptional() @IsInt() @Min(0) @Max(100) deviceBattery?: number;
  @IsDateString() startedAt!: string;
  @IsDateString() endedAt!: string;
  /** El paciente tocó "Terminar" antes de acabar la rutina. */
  @IsBoolean() endedEarly!: boolean;
  @IsOptional() @IsInt() @Min(0) @Max(10) painScore?: number;
  @IsOptional() @IsInt() @Min(0) @Max(10) effortScore?: number;
  @ValidateNested({ each: true }) @Type(() => SessionResultDto) @ArrayMaxSize(20) results!: SessionResultDto[];
  @IsOptional() @ValidateNested({ each: true }) @Type(() => SessionEventDto) @ArrayMaxSize(5000) events?: SessionEventDto[];
}
