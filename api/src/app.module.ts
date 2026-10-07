import { Controller, Get, Module } from '@nestjs/common';
import { AdherenceModule } from './adherence/adherence.module';
import { AuthModule } from './auth/auth.module';
import { AuditModule } from './common/audit.service';
import { PrismaModule } from './common/prisma.service';
import { ManagementModule } from './management/management.module';

@Controller()
class HealthController {
  @Get('health')
  health() {
    return { ok: true, service: 'smartshoulder-api' };
  }
}

@Module({
  imports: [PrismaModule, AuditModule, AuthModule, AdherenceModule, ManagementModule],
  controllers: [HealthController],
})
export class AppModule {}
