-- AlterTable
ALTER TABLE "animals" ADD COLUMN     "photoAttachmentId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "animals_photoAttachmentId_key" ON "animals"("photoAttachmentId");

-- AddForeignKey
ALTER TABLE "animals" ADD CONSTRAINT "animals_photoAttachmentId_fkey" FOREIGN KEY ("photoAttachmentId") REFERENCES "attachments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

