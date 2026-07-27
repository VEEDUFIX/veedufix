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

const prismaEvents = prisma as unknown as {
  $on(eventType: "query", callback: (event: { query: string; duration: number; target?: string }) => void): void;
  $on(eventType: "error", callback: (event: { message: string; target?: string }) => void): void;
};

prismaEvents.$on("query", (event) => {
  logger.debug({
    query: event.query,
    durationMs: event.duration,
    target: event.target
  });
});

prismaEvents.$on("error", (event) => {
  logger.error({ message: event.message, target: event.target });
});
