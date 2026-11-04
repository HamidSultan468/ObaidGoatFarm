import { Module } from '@nestjs/common';
import { LandController } from './land.controller.js';
import { LandService } from './land.service.js';

/** Land Management (Phase 07). Money flows through the ledger via JournalEntry.landParcelId. */
@Module({
  controllers: [LandController],
  providers: [LandService],
})
export class LandModule {}
