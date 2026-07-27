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

addressRouter.use(requireAuth, requireRole("CUSTOMER"));
addressRouter.post("/customer/addresses", validate(createAddressSchema), createAddressHandler);
addressRouter.get("/customer/addresses", validate(listAddressesSchema), listAddressesHandler);
addressRouter.put("/customer/addresses/:addressId", validate(updateAddressSchema), updateAddressHandler);
addressRouter.delete("/customer/addresses/:addressId", validate(deleteAddressSchema), deleteAddressHandler);
addressRouter.post(
  "/customer/addresses/:addressId/set-default",
  validate(setDefaultAddressSchema),
  setDefaultAddressHandler
);
