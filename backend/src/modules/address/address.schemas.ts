import { z } from "zod";

const addressIdParamsSchema = z.object({
  addressId: z.string().trim().min(1)
});

const emptyObjectSchema = z.object({}).strict();

const pincodeSchema = z
  .string()
  .trim()
  .regex(/^[1-9][0-9]{5}$/, "A valid 6-digit pincode is required")
  .refine(
    (val) => val.startsWith("600"),
    "We currently serve only Chennai (pincodes starting with 600)"
  );

const latSchema = z.coerce.number().min(-90).max(90);
const lngSchema = z.coerce.number().min(-180).max(180);

const createAddressBodySchema = z
  .object({
    label: z.string().trim().min(1).max(50),
    addressLine1: z.string().trim().min(3).max(255),
    addressLine2: z.string().trim().max(255).optional().or(z.literal("")),
    landmark: z.string().trim().max(255).optional().or(z.literal("")),
    city: z.string().trim().min(2).max(100),
    pincode: pincodeSchema,
    lat: latSchema,
    lng: lngSchema,
    isDefault: z.coerce.boolean().default(false)
  })
  .strict();

const updateAddressBodySchema = z
  .object({
    label: z.string().trim().min(1).max(50).optional(),
    addressLine1: z.string().trim().min(3).max(255).optional(),
    addressLine2: z.string().trim().max(255).optional().or(z.literal("")),
    landmark: z.string().trim().max(255).optional().or(z.literal("")),
    city: z.string().trim().min(2).max(100).optional(),
    pincode: pincodeSchema,
    lat: latSchema.optional(),
    lng: lngSchema.optional(),
    isDefault: z.coerce.boolean().optional()
  })
  .strict()
  .refine(
    (value) => Object.entries(value).some(([, entry]) => entry !== undefined && entry !== ""),
    {
      message: "At least one field must be provided"
    }
  );

export const createAddressSchema = z.object({
  body: createAddressBodySchema,
  query: emptyObjectSchema,
  params: emptyObjectSchema
});

export const listAddressesSchema = z.object({
  body: emptyObjectSchema,
  query: emptyObjectSchema,
  params: emptyObjectSchema
});

export const updateAddressSchema = z.object({
  body: updateAddressBodySchema,
  query: emptyObjectSchema,
  params: addressIdParamsSchema
});

export const deleteAddressSchema = z.object({
  body: emptyObjectSchema,
  query: emptyObjectSchema,
  params: addressIdParamsSchema
});

export const setDefaultAddressSchema = z.object({
  body: emptyObjectSchema,
  query: emptyObjectSchema,
  params: addressIdParamsSchema
});
