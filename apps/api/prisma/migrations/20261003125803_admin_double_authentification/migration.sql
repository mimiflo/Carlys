-- AlterTable
ALTER TABLE "AdminUser" ADD COLUMN     "totpEnabledAt" TIMESTAMP(3),
ADD COLUMN     "totpFailedAttempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "totpLastStep" INTEGER,
ADD COLUMN     "totpSecret" TEXT;
