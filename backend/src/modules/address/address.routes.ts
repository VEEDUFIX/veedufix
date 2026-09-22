import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  createAddressSchema,
  deleteAddressSchema,
  listAddressesSchema,
  setDefaultAddressSchema,
  updateAddressSchema
} from "./address.schemas.js";
import {
  createAddressHandler,
  deleteAddressHandler,
  listAddressesHandler,
  setDefaultAddressHandler,
  updateAddressHandler
} from "./address.controller.js";

export const addressRouter = Router();

const customerOnly = [requireAuth, requireRole("CUSTOMER")] as const;

addressRouter.post("/customer/addresses", ...customerOnly, validate(createAddressSchema), createAddressHandler);
addressRouter.get("/customer/addresses", ...customerOnly, validate(listAddressesSchema), listAddressesHandler);
addressRouter.put("/customer/addresses/:addressId", ...customerOnly, validate(updateAddressSchema), updateAddressHandler);
addressRouter.delete("/customer/addresses/:addressId", ...customerOnly, validate(deleteAddressSchema), deleteAddressHandler);
addressRouter.post(
  "/customer/addresses/:addressId/set-default",
  ...customerOnly,
  validate(setDefaultAddressSchema),
  setDefaultAddressHandler
);
