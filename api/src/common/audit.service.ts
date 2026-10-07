import { Global, Injectable, Module } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from './prisma.service';

/** Bitácora de auditoría (contexto/04 §5.4): cambios de prescripción, flota y accesos relevantes. */
@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  log(
    actorId: string | null,
    action: string,
    entity: string,
    entityId: string,
    diff?: Prisma.InputJsonValue,
    tx: Prisma.TransactionClient = this.prisma,
  ) {
    return tx.auditLog.create({ data: { actorId, action, entity, entityId, diff } });
  }
}

@Global()
@Module({ providers: [AuditService], exports: [AuditService] })
export class AuditModule {}
