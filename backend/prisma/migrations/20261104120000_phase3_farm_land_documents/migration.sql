-- CreateEnum
CREATE TYPE "AnimalSex" AS ENUM ('MALE', 'FEMALE');

-- CreateEnum
CREATE TYPE "AnimalStatus" AS ENUM ('ACTIVE', 'SOLD', 'DECEASED');

-- CreateEnum
CREATE TYPE "AnimalAcquisition" AS ENUM ('BORN_ON_FARM', 'PURCHASED', 'GIFTED', 'OTHER');

-- CreateEnum
CREATE TYPE "HealthRecordType" AS ENUM ('CHECKUP', 'ILLNESS', 'TREATMENT', 'VACCINATION', 'DEWORMING', 'MEDICATION', 'INJURY', 'OTHER');

-- CreateEnum
CREATE TYPE "BreedingMethod" AS ENUM ('NATURAL', 'ARTIFICIAL_INSEMINATION');

-- CreateEnum
CREATE TYPE "BreedingStatus" AS ENUM ('MATED', 'PREGNANT', 'NOT_PREGNANT', 'KIDDED', 'ABORTED');

-- CreateEnum
CREATE TYPE "AreaUnit" AS ENUM ('SQUARE_FOOT', 'SQUARE_METER', 'MARLA', 'KANAL', 'ACRE', 'HECTARE');

-- CreateEnum
CREATE TYPE "LandTenure" AS ENUM ('OWNED', 'LEASED_IN', 'LEASED_OUT', 'RENTED_OUT');

-- CreateEnum
CREATE TYPE "LandStatus" AS ENUM ('ACTIVE', 'SOLD', 'LEASE_ENDED');

-- CreateEnum
CREATE TYPE "AttachmentModule" AS ENUM ('ANIMAL', 'LAND', 'TRANSACTION', 'CONTACT', 'GENERAL');

-- AlterEnum
BEGIN;
CREATE TYPE "AnimalHealthStatus_new" AS ENUM ('HEALTHY', 'SICK', 'UNDER_TREATMENT', 'QUARANTINED');
ALTER TABLE "public"."animals" ALTER COLUMN "healthStatus" DROP DEFAULT;
ALTER TABLE "animals" ALTER COLUMN "healthStatus" TYPE "AnimalHealthStatus_new" USING ("healthStatus"::text::"AnimalHealthStatus_new");
ALTER TYPE "AnimalHealthStatus" RENAME TO "AnimalHealthStatus_old";
ALTER TYPE "AnimalHealthStatus_new" RENAME TO "AnimalHealthStatus";
DROP TYPE "public"."AnimalHealthStatus_old";
ALTER TABLE "animals" ALTER COLUMN "healthStatus" SET DEFAULT 'HEALTHY';
COMMIT;

-- AlterTable
ALTER TABLE "animals" ADD COLUMN     "acquisition" "AnimalAcquisition" NOT NULL DEFAULT 'PURCHASED',
ADD COLUMN     "acquisitionDate" TIMESTAMP(3),
ADD COLUMN     "breed" TEXT,
ADD COLUMN     "color" TEXT,
ADD COLUMN     "damId" TEXT,
ADD COLUMN     "dateOfBirth" TIMESTAMP(3),
ADD COLUMN     "dietaryRestrictions" TEXT,
ADD COLUMN     "exitDate" TIMESTAMP(3),
ADD COLUMN     "exitReason" TEXT,
ADD COLUMN     "name" TEXT,
ADD COLUMN     "notes" TEXT,
ADD COLUMN     "ownership" TEXT,
ADD COLUMN     "sex" "AnimalSex" NOT NULL,
ADD COLUMN     "sireId" TEXT,
ADD COLUMN     "species" TEXT NOT NULL DEFAULT 'GOAT',
ADD COLUMN     "status" "AnimalStatus" NOT NULL DEFAULT 'ACTIVE',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- AlterTable
ALTER TABLE "journal_entries" ADD COLUMN     "animalId" TEXT,
ADD COLUMN     "landParcelId" TEXT;

-- CreateTable
CREATE TABLE "animal_health_records" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "animalId" TEXT NOT NULL,
    "type" "HealthRecordType" NOT NULL,
    "recordDate" TIMESTAMP(3) NOT NULL,
    "description" TEXT NOT NULL,
    "medication" TEXT,
    "dosage" TEXT,
    "veterinarian" TEXT,
    "nextDueDate" TIMESTAMP(3),
    "createdByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "animal_health_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "animal_weight_records" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "animalId" TEXT NOT NULL,
    "recordDate" TIMESTAMP(3) NOT NULL,
    "weightKg" DECIMAL(8,3) NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "animal_weight_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "breeding_records" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "damId" TEXT NOT NULL,
    "sireId" TEXT,
    "externalSire" TEXT,
    "method" "BreedingMethod" NOT NULL DEFAULT 'NATURAL',
    "matingDate" TIMESTAMP(3) NOT NULL,
    "expectedKiddingDate" TIMESTAMP(3) NOT NULL,
    "status" "BreedingStatus" NOT NULL DEFAULT 'MATED',
    "kiddingDate" TIMESTAMP(3),
    "kidsBorn" INTEGER,
    "kidsAlive" INTEGER,
    "complications" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "breeding_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "land_parcels" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT,
    "surveyNumber" TEXT,
    "tenure" "LandTenure" NOT NULL DEFAULT 'OWNED',
    "status" "LandStatus" NOT NULL DEFAULT 'ACTIVE',
    "ownerName" TEXT,
    "areaValue" DECIMAL(18,4) NOT NULL,
    "areaUnit" "AreaUnit" NOT NULL,
    "areaSqFt" DECIMAL(18,4) NOT NULL,
    "landUse" TEXT,
    "acquisitionDate" TIMESTAMP(3),
    "counterpartyContactId" TEXT,
    "leaseStartDate" TIMESTAMP(3),
    "leaseEndDate" TIMESTAMP(3),
    "leaseTerms" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "land_parcels_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "module" "AttachmentModule" NOT NULL,
    "recordId" TEXT,
    "title" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "uploadedByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "animal_health_records_workspaceId_nextDueDate_idx" ON "animal_health_records"("workspaceId", "nextDueDate");

-- CreateIndex
CREATE INDEX "animal_health_records_animalId_recordDate_idx" ON "animal_health_records"("animalId", "recordDate");

-- CreateIndex
CREATE INDEX "animal_weight_records_animalId_recordDate_idx" ON "animal_weight_records"("animalId", "recordDate");

-- CreateIndex
CREATE INDEX "breeding_records_workspaceId_status_expectedKiddingDate_idx" ON "breeding_records"("workspaceId", "status", "expectedKiddingDate");

-- CreateIndex
CREATE INDEX "land_parcels_workspaceId_status_idx" ON "land_parcels"("workspaceId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "attachments_storageKey_key" ON "attachments"("storageKey");

-- CreateIndex
CREATE INDEX "attachments_workspaceId_module_recordId_idx" ON "attachments"("workspaceId", "module", "recordId");

-- CreateIndex
CREATE INDEX "animals_workspaceId_status_idx" ON "animals"("workspaceId", "status");

-- CreateIndex
CREATE INDEX "journal_entries_animalId_idx" ON "journal_entries"("animalId");

-- CreateIndex
CREATE INDEX "journal_entries_landParcelId_idx" ON "journal_entries"("landParcelId");

-- AddForeignKey
ALTER TABLE "journal_entries" ADD CONSTRAINT "journal_entries_animalId_fkey" FOREIGN KEY ("animalId") REFERENCES "animals"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "journal_entries" ADD CONSTRAINT "journal_entries_landParcelId_fkey" FOREIGN KEY ("landParcelId") REFERENCES "land_parcels"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "animals" ADD CONSTRAINT "animals_sireId_fkey" FOREIGN KEY ("sireId") REFERENCES "animals"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "animals" ADD CONSTRAINT "animals_damId_fkey" FOREIGN KEY ("damId") REFERENCES "animals"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "animal_health_records" ADD CONSTRAINT "animal_health_records_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "animal_health_records" ADD CONSTRAINT "animal_health_records_animalId_fkey" FOREIGN KEY ("animalId") REFERENCES "animals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "animal_weight_records" ADD CONSTRAINT "animal_weight_records_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "animal_weight_records" ADD CONSTRAINT "animal_weight_records_animalId_fkey" FOREIGN KEY ("animalId") REFERENCES "animals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "breeding_records" ADD CONSTRAINT "breeding_records_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "breeding_records" ADD CONSTRAINT "breeding_records_damId_fkey" FOREIGN KEY ("damId") REFERENCES "animals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "breeding_records" ADD CONSTRAINT "breeding_records_sireId_fkey" FOREIGN KEY ("sireId") REFERENCES "animals"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "land_parcels" ADD CONSTRAINT "land_parcels_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "land_parcels" ADD CONSTRAINT "land_parcels_counterpartyContactId_fkey" FOREIGN KEY ("counterpartyContactId") REFERENCES "contacts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

