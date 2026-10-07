import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class PrescriptionItemDto {
  @IsInt() @Min(1) @Max(6) exerciseId!: number;
  @IsInt() @Min(1) @Max(10) sets!: number;
  @IsInt() @Min(1) @Max(50) reps!: number;
  @IsInt() @Min(0) @Max(600) restSec!: number;
}

export class PrescriptionDto {
  /** Si viene una plantilla y no vienen items, se copian los de la plantilla. */
  @IsOptional() @IsString() templateId?: string;
  @IsOptional() @ValidateNested({ each: true }) @Type(() => PrescriptionItemDto) @ArrayMinSize(1) items?: PrescriptionItemDto[];
  @IsOptional() @IsInt() @Min(1) @Max(14) frequencyPerWeek?: number;
  @IsOptional() @IsDateString() startDate?: string;
  @IsOptional() @IsDateString() endDate?: string;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
}

/** Alta en un solo paso: paciente + prescripción + reloj (opcional) + código de invitación. */
export class CreatePatientDto {
  @IsString() @MinLength(2) @MaxLength(80) displayName!: string;
  @IsIn(['RIGHT', 'LEFT']) affectedArm!: 'RIGHT' | 'LEFT';
  @IsString() @MinLength(2) @MaxLength(200) diagnosis!: string;
  @ValidateNested() @Type(() => PrescriptionDto) prescription!: PrescriptionDto;
  @IsOptional() @IsString() deviceId?: string;
}

export class CreateDeviceDto {
  @IsString() @MinLength(4) @MaxLength(16) bleName!: string;
}

export class AssignDeviceDto {
  @IsString() patientId!: string;
}

export class DeviceStatusDto {
  @IsIn(['AVAILABLE', 'CLEANING', 'RETIRED']) status!: 'AVAILABLE' | 'CLEANING' | 'RETIRED';
}
