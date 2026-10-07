import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));

  const doc = new DocumentBuilder()
    .setTitle('SmartShoulder API')
    .setDescription('Backend compartido de la app del paciente y el dashboard del fisioterapeuta')
    .setVersion('0.1')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, doc));

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port, '0.0.0.0'); // 0.0.0.0: accesible desde el celular en la misma red
  console.log(`SmartShoulder API en http://localhost:${port}  ·  docs en /docs`);
}
bootstrap();
