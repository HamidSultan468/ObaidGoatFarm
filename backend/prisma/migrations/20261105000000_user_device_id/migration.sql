-- AlterTable
ALTER TABLE "user_devices" ADD COLUMN     "deviceId" TEXT NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "user_devices_userId_deviceId_key" ON "user_devices"("userId", "deviceId");
