import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Header,
  Injectable,
  Module,
  NotFoundException,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { JwtAuthGuard, RolesGuard } from '../auth/auth.guards';
import type { AuthUser } from '../auth/auth.types';
import { CurrentUser, Roles } from '../auth/auth.types';
import { CLINIC_TZ, dayRange } from '../common/clinic-time';
import { PrismaService } from '../common/prisma.service';
import { addDays, calendar, classifySession, dayKey } from './adherence.calc';
import { AdherenceService, patientScope } from './adherence.service';
import { CreateSessionDto } from './sessions.dto';

@Injectable()
export class SessionsService {
  constructor(private prisma: PrismaService) {}

  /** Lo que la app del paciente necesita para la sesión de hoy. */
  async me(user: AuthUser) {
    const p = await this.prisma.patient.findUnique({
      where: { id: user.patientId },
      include: {
        clinic: true,
        physio: { select: { name: true } },
        prescriptions: {
          where: { active: true },
          include: { items: { orderBy: { order: 'asc' }, include: { exercise: true } } },
          take: 1,
        },
        assignments: { where: { returnedAt: null }, include: { device: true }, take: 1 },
      },
    });
    if (!p) throw new NotFoundException();
    const rx = p.prescriptions[0];
    return {
      patient: { id: p.id, displayName: p.displayName, affectedArm: p.affectedArm },
      clinic: { name: p.clinic.name, logoUrl: p.clinic.logoUrl },
      physio: p.physio.name,
      device: p.assignments[0] ? { bleName: p.assignments[0].device.bleName } : null,
      prescription: rx
        ? {
            id: rx.id,
            frequencyPerWeek: rx.frequencyPerWeek,
            notes: rx.notes,
            exercises: rx.items.map((i) => ({
              exerciseId: i.exerciseId,
              name: i.exercise.name,
              instructions: i.exercise.instructions,
              videoUrl: i.exercise.videoUrl,
              sets: i.sets,
              reps: i.reps,
              restSec: i.restSec,
            })),
          }
        : null,
    };
  }

  async create(user: AuthUser, dto: CreateSessionDto) {
    const existing = await this.prisma.session.findUnique({ where: { clientSessionId: dto.clientSessionId } });
    if (existing) {
      if (existing.patientId !== user.patientId) throw new ForbiddenException();
      return { id: existing.id, status: existing.status, duplicate: true };
    }

    const rx = await this.prisma.prescription.findFirst({
      where: { id: dto.prescriptionId, patientId: user.patientId },
      include: { items: true },
    });
    if (!rx) throw new BadRequestException('Prescripción no válida');

    let device: { id: string } | null = null;
    if (dto.source === 'VERIFIED') {
      if (!dto.deviceBleName) throw new BadRequestException('Una sesión verificada requiere el dispositivo');
      device = await this.prisma.device.findFirst({
        where: { bleName: dto.deviceBleName, clinicId: user.clinicId },
      });
      if (!device) throw new BadRequestException('Dispositivo no registrado en la clínica');
    }

    // Resultados contra lo prescrito: el backend es la fuente de verdad de "completa".
    const results = rx.items.map((item) => {
      const done = dto.results.filter((r) => r.exerciseId === item.exerciseId);
      return {
        exerciseId: item.exerciseId,
        setsPrescribed: item.sets,
        repsPrescribed: item.sets * item.reps,
        setsDone: done.reduce((a, r) => a + r.setsDone, 0),
        repsDone: done.reduce((a, r) => a + r.repsDone, 0),
      };
    });
    const status = classifySession(results, dto.endedEarly);
    const patient = await this.prisma.patient.findUniqueOrThrow({ where: { id: user.patientId } });

    const session = await this.prisma.$transaction(async (tx) => {
      const s = await tx.session.create({
        data: {
          clientSessionId: dto.clientSessionId,
          patientId: patient.id,
          prescriptionId: rx.id,
          source: dto.source,
          deviceId: device?.id,
          fwVersion: dto.fwVersion,
          modelVersion: dto.modelVersion,
          startedAt: new Date(dto.startedAt),
          endedAt: new Date(dto.endedAt),
          status,
          painScore: dto.painScore,
          effortScore: dto.effortScore,
          isDemo: patient.isDemo,
          results: { create: results },
          events: dto.events?.length ? { createMany: { data: dto.events, skipDuplicates: true } } : undefined,
        },
      });
      if (device) {
        await tx.device.update({
          where: { id: device.id },
          data: {
            lastSeenAt: new Date(dto.endedAt),
            lastBattery: dto.deviceBattery,
            fwVersion: dto.fwVersion,
            modelVersion: dto.modelVersion,
          },
        });
      }
      return s;
    });
    return { id: session.id, status: session.status, duplicate: false };
  }

  async mySessions(user: AuthUser, from: string, to: string) {
    const sessions = await this.prisma.session.findMany({
      where: { patientId: user.patientId },
      include: { results: { include: { exercise: { select: { name: true } } } } },
      orderBy: { startedAt: 'desc' },
      take: 200,
    });
    const inRange = sessions.filter((s) => {
      const k = dayKey(s.startedAt, CLINIC_TZ);
      return k >= from && k <= to;
    });
    const streak = this.streak(sessions.map((s) => ({ day: dayKey(s.startedAt, CLINIC_TZ), complete: s.status === 'COMPLETE' })));
    return { calendar: calendar(inRange, from, to, CLINIC_TZ), streak, sessions: inRange.map(sessionView) };
  }

  /** Días seguidos (hasta hoy o ayer) con al menos una sesión completa. */
  private streak(days: { day: string; complete: boolean }[]): number {
    const complete = new Set(days.filter((d) => d.complete).map((d) => d.day));
    let d = dayKey(new Date(), CLINIC_TZ);
    if (!complete.has(d)) d = addDays(d, -1);
    let n = 0;
    while (complete.has(d)) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }
}

function sessionView(s: {
  id: string;
  startedAt: Date;
  endedAt: Date;
  status: string;
  source: string;
  painScore: number | null;
  effortScore: number | null;
  results: { exerciseId: number; repsDone: number; repsPrescribed: number; setsDone: number; setsPrescribed: number; exercise: { name: string } }[];
}) {
  return {
    id: s.id,
    day: dayKey(s.startedAt, CLINIC_TZ),
    startedAt: s.startedAt,
    durationSec: Math.round((s.endedAt.getTime() - s.startedAt.getTime()) / 1000),
    status: s.status,
    source: s.source,
    painScore: s.painScore,
    effortScore: s.effortScore,
    results: s.results.map((r) => ({
      exerciseId: r.exerciseId,
      name: r.exercise.name,
      repsDone: r.repsDone,
      repsPrescribed: r.repsPrescribed,
      setsDone: r.setsDone,
      setsPrescribed: r.setsPrescribed,
    })),
  };
}

// ============================================================ controladores

@ApiTags('paciente')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.PATIENT)
@Controller()
export class PatientAppController {
  constructor(private sessions: SessionsService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.sessions.me(user);
  }

  @Get('me/sessions')
  mySessions(@CurrentUser() user: AuthUser, @Query('from') from?: string, @Query('to') to?: string) {
    const r = dayRange(from, to, 35);
    return this.sessions.mySessions(user, r.from, r.to);
  }

  @Post('sessions')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateSessionDto) {
    return this.sessions.create(user, dto);
  }
}

@ApiTags('reportes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.PHYSIO, Role.CLINIC_ADMIN)
@Controller()
export class ReportsController {
  constructor(
    private adherence: AdherenceService,
    private prisma: PrismaService,
  ) {}

  @Get('patients/:id/adherence')
  adherenceDetail(@CurrentUser() user: AuthUser, @Param('id') id: string, @Query('from') from?: string, @Query('to') to?: string) {
    const r = dayRange(from, to);
    return this.adherence.detail(user, id, r.from, r.to);
  }

  @Get('patients/:id/sessions')
  async patientSessions(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const sessions = await this.prisma.session.findMany({
      where: { patientId: id, patient: patientScope(user) },
      include: { results: { include: { exercise: { select: { name: true } } } }, device: { select: { bleName: true } } },
      orderBy: { startedAt: 'desc' },
      take: 100,
    });
    return sessions.map((s) => ({ ...sessionView(s), device: s.device?.bleName ?? null, modelVersion: s.modelVersion }));
  }

  @Get('patients/:id/export.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  async exportCsv(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const p = await this.prisma.patient.findFirst({ where: { id, ...patientScope(user) } });
    if (!p) throw new NotFoundException();
    const sessions = await this.prisma.session.findMany({
      where: { patientId: id },
      include: { results: { include: { exercise: true } }, device: true },
      orderBy: { startedAt: 'asc' },
    });
    const header = 'fecha,inicio,origen,estado,dispositivo,version_modelo,ejercicio,series_hechas,series_prescritas,reps_hechas,reps_prescritas,dolor,esfuerzo';
    const lines = sessions.flatMap((s) =>
      s.results.map((r) =>
        [
          dayKey(s.startedAt, CLINIC_TZ),
          s.startedAt.toISOString(),
          s.source === 'VERIFIED' ? 'verificado por el dispositivo' : 'reportado por el paciente',
          s.status,
          s.device?.bleName ?? '',
          s.modelVersion ?? '',
          `"${r.exercise.name}"`,
          r.setsDone,
          r.setsPrescribed,
          r.repsDone,
          r.repsPrescribed,
          s.painScore ?? '',
          s.effortScore ?? '',
        ].join(','),
      ),
    );
    return '﻿' + [`# ${p.displayName} — datos de ejecución registrados; no constituye evaluación clínica`, header, ...lines].join('\n');
  }

  @Get('clinic/kpis')
  kpis(@CurrentUser() user: AuthUser) {
    return this.adherence.kpis(user);
  }
}

@Module({
  controllers: [PatientAppController, ReportsController],
  providers: [AdherenceService, SessionsService],
  exports: [AdherenceService],
})
export class AdherenceModule {}
