import { Module } from '@nestjs/common';
import { AnimalsController } from './animals/animals.controller.js';
import { AnimalsService } from './animals/animals.service.js';
import { BreedingController } from './breeding/breeding.controller.js';
import { BreedingService } from './breeding/breeding.service.js';
import { FarmOverviewController } from './overview/farm-overview.controller.js';
import { FarmOverviewService } from './overview/farm-overview.service.js';

/** Goat Farm Management (Phase 06). Money flows through AccountingModule's ledger via JournalEntry.animalId. */
@Module({
  controllers: [AnimalsController, BreedingController, FarmOverviewController],
  providers: [AnimalsService, BreedingService, FarmOverviewService],
  exports: [AnimalsService, FarmOverviewService],
})
export class FarmModule {}
