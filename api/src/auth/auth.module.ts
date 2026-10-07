import { Body, Controller, Injectable, Module, Post, UnauthorizedException } from '@nestjs/common';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { IsEmail, IsString, Length, MinLength } from 'class-validator';
import { PrismaService } from '../common/prisma.service';
import { JwtStrategy } from './auth.guards';
import { AuthUser } from './auth.types';

class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(6) password!: string;
}

class RedeemDto {
  @IsString() @Length(6, 6) code!: string;
}

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  /** Fisioterapeuta o admin de clínica (dashboard web). */
  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: { clinic: true },
    });
    if (!user?.passwordHash || user.role === Role.PATIENT || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Correo o contraseña incorrectos');
    }
    const payload: AuthUser = { sub: user.id, role: user.role, clinicId: user.clinicId };
    return {
      token: await this.jwt.signAsync(payload, { expiresIn: '12h' }),
      user: { id: user.id, name: user.name, role: user.role, clinic: { id: user.clinic.id, name: user.clinic.name } },
    };
  }

  /**
   * Paciente: entra a la app con el código que genera el fisio (sin contraseña).
   * El código se puede volver a usar mientras no expire, por si el paciente reinstala la app.
   */
  async redeem(code: string) {
    const invite = await this.prisma.inviteCode.findUnique({
      where: { code: code.toUpperCase() },
      include: { patient: true },
    });
    if (!invite || invite.expiresAt < new Date() || invite.patient.archivedAt) {
      throw new UnauthorizedException('El código no es válido o ya venció. Pide uno nuevo a tu fisioterapeuta.');
    }
    const patient = invite.patient;
    let userId = patient.userId;
    if (!userId) {
      const user = await this.prisma.user.create({
        data: { clinicId: patient.clinicId, role: Role.PATIENT, name: patient.displayName },
      });
      await this.prisma.patient.update({ where: { id: patient.id }, data: { userId: user.id } });
      userId = user.id;
    }
    if (!invite.usedAt) {
      await this.prisma.inviteCode.update({ where: { code: invite.code }, data: { usedAt: new Date() } });
    }
    const payload: AuthUser = { sub: userId, role: Role.PATIENT, clinicId: patient.clinicId, patientId: patient.id };
    return { token: await this.jwt.signAsync(payload, { expiresIn: '90d' }) };
  }
}

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @Post('redeem')
  redeem(@Body() dto: RedeemDto) {
    return this.auth.redeem(dto.code);
  }
}

@Module({
  imports: [PassportModule, JwtModule.register({ secret: process.env.JWT_SECRET ?? 'dev-secret' })],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
})
export class AuthModule {}
