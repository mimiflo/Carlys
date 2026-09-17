-- CreateEnum
CREATE TYPE "MentorStyle" AS ENUM ('BIENVEILLANT', 'EXIGEANT', 'ATHLETE', 'PHILOSOPHE');

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN     "mentorStyle" "MentorStyle";
