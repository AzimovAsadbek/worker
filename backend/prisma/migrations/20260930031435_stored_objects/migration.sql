-- CreateTable
CREATE TABLE "StoredObject" (
    "key" TEXT NOT NULL,
    "contentType" VARCHAR(80) NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "data" BYTEA NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StoredObject_pkey" PRIMARY KEY ("key")
);
