import { Module } from "@nestjs/common";
import { RoomModule } from "./room/room.module";
import { HealthController } from "./health/health.controller";

@Module({
  imports: [RoomModule],
  controllers: [HealthController],
})
export class AppModule {}
