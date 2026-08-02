import { PrismaClient } from "@prisma/client";
import { logger } from "./logger.js";

type PrismaModelDelegate = {
  findMany(args?: any): Promise<Array<Record<string, any>>>;
  findFirst(args?: any): Promise<any>;
  findUnique(args?: any): Promise<any>;
  create(args?: any): Promise<any>;
  createMany(args?: any): Promise<any>;
  update(args?: any): Promise<any>;
  updateMany(args?: any): Promise<any>;
  delete(args?: any): Promise<any>;
  deleteMany(args?: any): Promise<any>;
  upsert(args?: any): Promise<any>;
  count(args?: any): Promise<any>;
  aggregate(args?: any): Promise<any>;
  groupBy(args?: any): Promise<any>;
};

export type AppPrismaClient = {
  $connect(): Promise<void>;
  $disconnect(): Promise<void>;
  $transaction<P extends Array<Promise<any>>>(arg: [...P], options?: any): Promise<{ [K in keyof P]: Awaited<P[K]> }>;
  $transaction<R>(fn: (tx: AppPrismaClient) => Promise<R>, options?: any): Promise<R>;
  $on(eventType: string, callback: (...args: any[]) => void): void;
} & Record<string, PrismaModelDelegate>;

declare global {
  // eslint-disable-next-line no-var
  var prisma: AppPrismaClient | undefined;
}

export const prisma =
  globalThis.prisma ??
  (new PrismaClient({
    log: [{ emit: "event", level: "query" }, { emit: "event", level: "error" }]
  }) as unknown as AppPrismaClient);

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
