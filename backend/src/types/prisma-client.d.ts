declare module "@prisma/client" {
  export class PrismaClient {
    [key: string]: any;
    constructor(...args: any[]);
    $connect(): Promise<void>;
    $disconnect(): Promise<void>;
    $transaction(...args: any[]): any;
  }

  export namespace Prisma {
    export class Decimal {
      [key: string]: any;
      constructor(value?: any);
      toNumber(): number;
      toString(): string;
      toFixed(fractionDigits?: number): string;
      add(value: any): Decimal;
      sub(value: any): Decimal;
      mul(value: any): Decimal;
      div(value: any): Decimal;
      lt(value: any): boolean;
      lte(value: any): boolean;
      gt(value: any): boolean;
      gte(value: any): boolean;
      eq(value: any): boolean;
    }

    export const DbNull: any;
    export const JsonNull: any;
    export const AnyNull: any;

    export class PrismaClientKnownRequestError extends Error {
      code: string;
      clientVersion: string;
      meta?: Record<string, unknown>;
      constructor(message: string, options?: { code?: string; clientVersion?: string; meta?: Record<string, unknown> });
    }

    export class PrismaClientUnknownRequestError extends Error {}
    export class PrismaClientRustPanicError extends Error {}
    export class PrismaClientInitializationError extends Error {}
    export class PrismaClientValidationError extends Error {}

    export type PrismaPromise<T> = Promise<T>;
    export type TransactionClient = any;
    export type TransactionIsolationLevel = string;

    export type InputJsonValue = any;
    export type JsonValue = any;
    export type JsonObject = any;
    export type JsonArray = any;
    export type InputJsonObject = any;
    export type InputJsonArray = any;
    export type DecimalJsLike = any;
    export type Metrics = any;
    export type Metric<T> = any;
    export type MetricHistogram = any;
    export type MetricHistogramBucket = any;
    export type FieldRef<Model, FieldType> = any;
    export type SqlDriverAdapterFactory = any;
    export type BaseDMMF = any;

    export const validator: <T>(value: T) => T;
    export const sql: any;
    export const empty: any;
    export const join: any;
    export const raw: any;
    export const Sql: any;
    export const Bytes: any;
    export const dmmf: any;
    export const getExtensionContext: any;

    export type SavedAddressUpdateInput = Record<string, any>;
    export type BookingGetPayload<T = any> = any;
    export type ServiceCategoryInclude = any;
    export type ServiceInclude = any;
    export type ServiceWhereInput = any;
    export type DateTimeFilter = any;
    export type PayoutGetPayload<T = any> = any;
    export type PayoutUpdateInput = Record<string, any>;
    export type PayoutWhereInput = any;
    export type PaymentGetPayload<T = any> = any;
    export type InvoiceGetPayload<T = any> = any;
    export type WorkerProfileGetPayload<T = any> = any;
    export type WorkerProfileWhereInput = any;
    export type WorkerSkillGetPayload<T = any> = any;
    export type ReviewGetPayload<T = any> = any;
    export type OpsAlertGetPayload<T = any> = any;
    export type OpsAlertWhereInput = any;
    export type RefundGetPayload<T = any> = any;
    export type RefundWhereInput = any;
    export type ServiceAreaGetPayload<T = any> = any;
    export type ServiceAreaUpdateInput = Record<string, any>;
    export type ServiceAreaWhereInput = any;
  }

  export enum BookingStatus {
    PENDING = "PENDING",
    ACCEPTED = "ACCEPTED",
    WORKER_ASSIGNED = "WORKER_ASSIGNED",
    ARRIVED = "ARRIVED",
    IN_PROGRESS = "IN_PROGRESS",
    COMPLETED = "COMPLETED",
    CANCELLED = "CANCELLED",
    CANCELLED_MANUAL = "CANCELLED_MANUAL",
    CANCELLED_NO_SHOW = "CANCELLED_NO_SHOW",
    DISPATCH_FAILED = "DISPATCH_FAILED",
    REFUNDED = "REFUNDED"
  }

  export enum PaymentStatus {
    PENDING = "PENDING",
    CAPTURED = "CAPTURED",
    FAILED = "FAILED",
    REFUNDED = "REFUNDED"
  }

  export enum VerificationStatus {
    PENDING = "PENDING",
    VERIFIED = "VERIFIED",
    REJECTED = "REJECTED",
    SUSPENDED = "SUSPENDED"
  }

  export enum UserRole {
    CUSTOMER = "CUSTOMER",
    WORKER = "WORKER",
    ADMIN = "ADMIN"
  }

  export enum Gender {
    MALE = "MALE",
    FEMALE = "FEMALE",
    OTHER = "OTHER"
  }

  export enum PriceRuleType {
    BASE = "BASE",
    CITY = "CITY",
    SEASONAL = "SEASONAL",
    PROMOTIONAL = "PROMOTIONAL",
    SURGE = "SURGE",
    WORKER = "WORKER"
  }

  export enum CouponType {
    PERCENTAGE = "PERCENTAGE",
    FIXED = "FIXED"
  }

  export enum ReviewStatus {
    PENDING = "PENDING",
    PUBLISHED = "PUBLISHED",
    HIDDEN = "HIDDEN"
  }
}
