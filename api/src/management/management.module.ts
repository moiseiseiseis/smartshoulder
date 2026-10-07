import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Prisma, Role } from '@prisma/client';
import { randomInt } from 'crypto';
import { AdherenceModule } from '../adherence/adherence.module';
import { AdherenceService, patientScope } from '../adherence/adherence.service';
import { JwtAuthGuard, RolesGuard } from '../auth/auth.guards';
import type { AuthUser } from '../auth/auth.types';
import { CurrentUser, Roles } from '../auth/auth.types';
import { AuditService } from '../common/audit.service';
import { PrismaService } from '../common/prisma.service';
import {
  AssignDeviceDto,
  CreateDeviceDto,
  CreatePatientDto,
  DeviceStatusDto,
  PrescriptionDto,
} from './management.dto';

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0/O ni 1/I
const INVITE_DAYS = 14;

type Tx = Prisma.TransactionClient;

@Injectable()
export class FleetService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  /** Asigna un reloj a un paciente. Si el paciente tenía otro, ese pasa a limpieza. */
  async assign(tx: Tx, user: AuthUser, deviceId: string, patientId: string) {
    const device = await tx.device.findFirst({ where: { id: deviceId, clinicId: user.clinicId } });
    if (!device) throw new NotFoundException('Reloj no encontrado');
    const open = await tx.deviceAssignment.findFirst({ where: { patientId, returnedAt: null } });
    if (open?.deviceId === deviceId) return;
    if (device.status !== 'AVAILABLE') throw new BadRequestException(`El reloj ${device.bleName} no está disponible`);
    if (open) await this.release(tx, user, open.deviceId);
    await tx.deviceAssignment.create({ data: { deviceId, patientId } });
    await tx.device.update({ where: { id: deviceId }, data: { status: 'ASSIGNED' } });
    await this.audit.log(user.sub, 'device.assign', 'Device', deviceId, { patientId }, tx);
  }

  /** Devolución: el reloj regresa a la clínica y queda en limpieza antes de prestarse otra vez. */
  async release(tx: Tx, user: AuthUser, deviceId: string) {
    const open = await tx.deviceAssignment.findFirst({ where: { deviceId, returnedAt: null } });
    if (open) await tx.deviceAssignment.update({ where: { id: open.id }, data: { returnedAt: new Date() } });
    await tx.device.update({ where: { id: deviceId }, data: { status: 'CLEANING' } });
    await this.audit.log(user.sub, 'device.return', 'Device', deviceId, { patientId: open?.patientId ?? null }, tx);
  }
}

@Injectable()
export class PatientsService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private fleet: FleetService,
  ) {}

  async create(user: AuthUser, dto: CreatePatientDto) {
    const physioId = user.sub;
    return this.prisma.$transaction(async (tx) => {
      const patient = await tx.patient.create({
        data: {
          clinicId: user.clinicId,
          physioId,
          displayName: dto.displayName.trim(),
          affectedArm: dto.affectedArm,
          diagnosis: dto.diagnosis.trim(),
        },
      });
      await this.audit.log(user.sub, 'patient.create', 'Patient', patient.id, undefined, tx);
      await this.createPrescription(tx, user, patient.id, dto.prescription);
      if (dto.deviceId) await this.fleet.assign(tx, user, dto.deviceId, patient.id);
      const invite = await this.newInvite(tx, patient.id);
      return { id: patient.id, invite };
    });
  }

  async get(user: AuthUser, id: string) {
    const p = await this.prisma.patient.findFirst({
      where: { id, ...patientScope(user) },
      include: {
        physio: { select: { name: true } },
        prescriptions: {
          orderBy: { createdAt: 'desc' },
          include: {
            items: { orderBy: { order: 'asc' }, include: { exercise: { select: { name: true } } } },
            template: { select: { name: true } },
            createdBy: { select: { name: true } },
          },
        },
        assignments: { where: { returnedAt: null }, include: { device: true }, take: 1 },
        invites: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });
    if (!p) throw new NotFoundException('Paciente no encontrado');
    const device = p.assignments[0]?.device;
    const invite = p.invites[0];
    return {
      id: p.id,
      displayName: p.displayName,
      affectedArm: p.affectedArm,
      diagnosis: p.diagnosis,
      isDemo: p.isDemo,
      physio: p.physio.name,
      createdAt: p.createdAt,
      archivedAt: p.archivedAt,
      appLinked: !!p.userId,
      device: device
        ? { id: device.id, bleName: device.bleName, lastBattery: device.lastBattery, lastSeenAt: device.lastSeenAt, modelVersion: device.modelVersion }
        : null,
      invite: invite ? { code: invite.code, expiresAt: invite.expiresAt, usedAt: invite.usedAt, qr: inviteQr(invite.code, device?.bleName) } : null,
      prescription: p.prescriptions.find((r) => r.active) ?? null,
      prescriptionHistory: p.prescriptions.map((r) => ({
        id: r.id,
        createdAt: r.createdAt,
        createdBy: r.createdBy.name,
        template: r.template?.name ?? null,
        frequencyPerWeek: r.frequencyPerWeek,
        items: r.items.map((i) => `${i.exercise.name} ${i.sets}×${i.reps}`),
        active: r.active,
      })),
    };
  }

  async prescribe(user: AuthUser, patientId: string, dto: PrescriptionDto) {
    await this.ensureAccess(user, patientId);
    return this.prisma.$transaction((tx) => this.createPrescription(tx, user, patientId, dto));
  }

  async regenerateInvite(user: AuthUser, patientId: string) {
    await this.ensureAccess(user, patientId);
    return this.prisma.$transaction((tx) => this.newInvite(tx, patientId));
  }

  /** Alta del paciente: se archiva y su reloj regresa a la clínica. */
  async discharge(user: AuthUser, patientId: string) {
    await this.ensureAccess(user, patientId);
    return this.prisma.$transaction(async (tx) => {
      const open = await tx.deviceAssignment.findFirst({ where: { patientId, returnedAt: null } });
      if (open) await this.fleet.release(tx, user, open.deviceId);
      await tx.prescription.updateMany({ where: { patientId, active: true }, data: { active: false } });
      await tx.patient.update({ where: { id: patientId }, data: { archivedAt: new Date() } });
      await this.audit.log(user.sub, 'patient.discharge', 'Patient', patientId, undefined, tx);
      return { ok: true };
    });
  }

  private async ensureAccess(user: AuthUser, patientId: string) {
    const p = await this.prisma.patient.findFirst({ where: { id: patientId, ...patientScope(user) } });
    if (!p) throw new NotFoundException('Paciente no encontrado');
    return p;
  }

  private async createPrescription(tx: Tx, user: AuthUser, patientId: string, dto: PrescriptionDto) {
    let items = dto.items;
    let frequency = dto.frequencyPerWeek;
    if (dto.templateId) {
      const t = await tx.protocolTemplate.findFirst({
        where: { id: dto.templateId, OR: [{ clinicId: null }, { clinicId: user.clinicId }] },
        include: { items: { orderBy: { order: 'asc' } } },
      });
      if (!t) throw new BadRequestException('Plantilla no encontrada');
      items ??= t.items.map(({ exerciseId, sets, reps, restSec }) => ({ exerciseId, sets, reps, restSec }));
      frequency ??= t.frequencyPerWeek;
    }
    if (!items?.length || !frequency) throw new BadRequestException('La prescripción necesita ejercicios y frecuencia');

    const previous = await tx.prescription.findFirst({ where: { patientId, active: true }, include: { items: true } });
    await tx.prescription.updateMany({ where: { patientId, active: true }, data: { active: false } });
    const rx = await tx.prescription.create({
      data: {
        patientId,
        templateId: dto.templateId,
        frequencyPerWeek: frequency,
        startDate: dto.startDate ? new Date(dto.startDate) : new Date(),
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        notes: dto.notes,
        createdById: user.sub,
        items: { create: items.map((i, order) => ({ ...i, order })) },
      },
      include: { items: true },
    });
    await this.audit.log(
      user.sub,
      previous ? 'prescription.change' : 'prescription.create',
      'Prescription',
      rx.id,
      {
        before: previous ? previous.items.map(({ exerciseId, sets, reps, restSec }) => ({ exerciseId, sets, reps, restSec })) : null,
        after: items.map(({ exerciseId, sets, reps, restSec }) => ({ exerciseId, sets, reps, restSec })),
        frequencyPerWeek: frequency,
      } as Prisma.InputJsonValue,
      tx,
    );
    return rx;
  }

  private async newInvite(tx: Tx, patientId: string) {
    const code = Array.from({ length: 6 }, () => INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)]).join('');
    const expiresAt = new Date(Date.now() + INVITE_DAYS * 86_400_000);
    const invite = await tx.inviteCode.create({ data: { code, patientId, expiresAt } });
    const device = await tx.deviceAssignment.findFirst({
      where: { patientId, returnedAt: null },
      include: { device: true },
    });
    return { code: invite.code, expiresAt, qr: inviteQr(invite.code, device?.device.bleName) };
  }
}

/** Contenido del QR que escanea la app: código de invitación + reloj asignado. */
export function inviteQr(code: string, bleName?: string | null) {
  return `smartshoulder://invite?code=${code}${bleName ? `&device=${bleName}` : ''}`;
}

// ============================================================ controladores

@ApiTags('pacientes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.PHYSIO, Role.CLINIC_ADMIN)
@Controller('patients')
export class PatientsController {
  constructor(
    private patients: PatientsService,
    private adherence: AdherenceService,
  ) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.adherence.patientRows(user);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePatientDto) {
    return this.patients.create(user, dto);
  }

  @Get(':id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.patients.get(user, id);
  }

  @Post(':id/prescriptions')
  prescribe(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: PrescriptionDto) {
    return this.patients.prescribe(user, id, dto);
  }

  @Post(':id/invite')
  invite(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.patients.regenerateInvite(user, id);
  }

  @Post(':id/discharge')
  discharge(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.patients.discharge(user, id);
  }
}

@ApiTags('relojes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.PHYSIO, Role.CLINIC_ADMIN)
@Controller('devices')
export class DevicesController {
  constructor(
    private prisma: PrismaService,
    private fleet: FleetService,
    private audit: AuditService,
  ) {}

  @Get()
  async list(@CurrentUser() user: AuthUser) {
    const devices = await this.prisma.device.findMany({
      where: { clinicId: user.clinicId },
      include: {
        assignments: { where: { returnedAt: null }, include: { patient: { select: { id: true, displayName: true } } } },
        _count: { select: { assignments: true } },
      },
      orderBy: { bleName: 'asc' },
    });
    return devices.map((d) => ({
      id: d.id,
      bleName: d.bleName,
      status: d.status,
      isDemo: d.isDemo,
      lastBattery: d.lastBattery,
      lastSeenAt: d.lastSeenAt,
      fwVersion: d.fwVersion,
      modelVersion: d.modelVersion,
      patient: d.assignments[0]?.patient ?? null,
      patientsServed: d._count.assignments, // métrica clave del hardware (contexto/app.md §6.3)
    }));
  }

  @Post()
  @Roles(Role.CLINIC_ADMIN, Role.PHYSIO)
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateDeviceDto) {
    const bleName = dto.bleName.trim().toUpperCase();
    const exists = await this.prisma.device.findUnique({ where: { bleName } });
    if (exists) throw new BadRequestException(`El reloj ${bleName} ya está registrado`);
    const d = await this.prisma.device.create({ data: { clinicId: user.clinicId, bleName } });
    await this.audit.log(user.sub, 'device.create', 'Device', d.id);
    return d;
  }

  @Post(':id/assign')
  async assign(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: AssignDeviceDto) {
    const patient = await this.prisma.patient.findFirst({ where: { id: dto.patientId, ...patientScope(user), archivedAt: null } });
    if (!patient) throw new NotFoundException('Paciente no encontrado');
    await this.prisma.$transaction((tx) => this.fleet.assign(tx, user, id, dto.patientId));
    return { ok: true };
  }

  @Post(':id/return')
  async return(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.ensureDevice(user, id);
    await this.prisma.$transaction((tx) => this.fleet.release(tx, user, id));
    return { ok: true };
  }

  @Patch(':id/status')
  async status(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: DeviceStatusDto) {
    const d = await this.ensureDevice(user, id);
    if (d.status === 'ASSIGNED') throw new BadRequestException('Primero registra la devolución del reloj');
    await this.prisma.device.update({ where: { id }, data: { status: dto.status } });
    await this.audit.log(user.sub, 'device.status', 'Device', id, { from: d.status, to: dto.status });
    return { ok: true };
  }

  private async ensureDevice(user: AuthUser, id: string) {
    const d = await this.prisma.device.findFirst({ where: { id, clinicId: user.clinicId } });
    if (!d) throw new NotFoundException('Reloj no encontrado');
    return d;
  }
}

@ApiTags('catálogo')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class CatalogController {
  constructor(private prisma: PrismaService) {}

  @Get('exercises')
  exercises() {
    return this.prisma.exercise.findMany({ where: { enabled: true, id: { gt: 0 } }, orderBy: { id: 'asc' } });
  }

  @Get('templates')
  templates(@CurrentUser() user: AuthUser) {
    return this.prisma.protocolTemplate.findMany({
      where: { OR: [{ clinicId: null }, { clinicId: user.clinicId }] },
      include: { items: { orderBy: { order: 'asc' }, include: { exercise: { select: { name: true } } } } },
      orderBy: { name: 'asc' },
    });
  }
}

@Module({
  imports: [AdherenceModule],
  controllers: [PatientsController, DevicesController, CatalogController],
  providers: [PatientsService, FleetService],
})
export class ManagementModule {}
