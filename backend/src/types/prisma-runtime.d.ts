declare module "@prisma/client/runtime/library" {
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

  export namespace Types {
    namespace Public {
      type PrismaPromise<T> = Promise<T>;
    }

    namespace Utils {
      type JsPromise<T> = Promise<T>;
      type UnwrapTuple<T> = T extends readonly (infer U)[] ? U[] : T;
    }

    namespace Extensions {
      function getExtensionContext<T>(value: T): any;
    }

    namespace Result {
      type DefaultSelection<T> = T;
    }
  }

  export namespace Public {
    const validator: <T>(value: T) => T;
  }

  export namespace Extensions {
    function getExtensionContext<T>(value: T): any;
  }

  export const DMMF: any;
  export const PrismaClientKnownRequestError: any;
  export const PrismaClientUnknownRequestError: any;
  export const PrismaClientRustPanicError: any;
  export const PrismaClientInitializationError: any;
  export const PrismaClientValidationError: any;
  export const sqltag: any;
  export const empty: any;
  export const join: any;
  export const raw: any;
  export const Sql: any;
  export type DecimalJsLike = any;
  export type Metrics = any;
  export type Metric<T> = any;
  export type MetricHistogram = any;
  export type MetricHistogramBucket = any;
  export const Bytes: any;
  export type JsonObject = any;
  export type JsonArray = any;
  export type JsonValue = any;
  export type InputJsonObject = any;
  export type InputJsonArray = any;
  export type InputJsonValue = any;
  export type FieldRef<Model, FieldType> = any;
  export type SqlDriverAdapterFactory = any;
  export type BaseDMMF = any;
  export const ITXClientDenyList: readonly string[];
}
