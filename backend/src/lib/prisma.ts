import { PrismaClient } from "@prisma/client";
import { logger } from "./logger.js";

declare global {
  // eslint-disable-next-line no-var
  var prisma: PrismaClient | undefined;
}

export const prisma =
  globalThis.prisma ??
  new PrismaClient({
    log: [{ emit: "event", level: "query" }, { emit: "event", level: "error" }]
  });

if (!globalThis.prisma) {
  globalThis.prisma = prisma;
}

prisma.$on("query", (event) => {
  logger.debug({
    query: event.query,
    durationMs: event.duration,
    target: event.target
  });
});

prisma.$on("error", (event) => {
  logger.error({ message: event.message, target: event.target });
});
