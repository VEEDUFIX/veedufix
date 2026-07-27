import { type NextFunction, type Response } from "express";
import { type AuthenticatedRequest } from "../../middleware/auth.js";
import {
  SavedAddressNotFoundError,
  createAddress,
  deleteAddress,
  listAddresses,
  setDefaultAddress,
  updateAddress
} from "./address.service.js";

function sendError(response: Response, error: unknown): void {
  if (error instanceof SavedAddressNotFoundError) {
    response.status(404).json({ message: error.message });
    return;
  }

  if (error instanceof Error) {
    response.status(400).json({ message: error.message });
    return;
  }

  response.status(500).json({ message: "Unexpected error" });
}

function requireCustomer(request: AuthenticatedRequest, response: Response): boolean {
  if (!request.auth) {
    response.status(401).json({ message: "Authentication required" });
    return false;
  }

  if (request.auth.role !== "CUSTOMER") {
    response.status(403).json({ message: "Insufficient permissions" });
    return false;
  }

  return true;
}

export async function createAddressHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireCustomer(request, response)) {
    return;
  }

  try {
    const address = await createAddress(request.auth!.userId, request.body);
    response.status(201).json({ address });
  } catch (error) {
    sendError(response, error);
  }
}

export async function listAddressesHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireCustomer(request, response)) {
    return;
  }

  try {
    const addresses = await listAddresses(request.auth!.userId);
    response.status(200).json({ addresses });
  } catch (error) {
    sendError(response, error);
  }
}

export async function updateAddressHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireCustomer(request, response)) {
    return;
  }

  try {
    const address = await updateAddress(request.auth!.userId, String(request.params.addressId), request.body);
    response.status(200).json({ address });
  } catch (error) {
    sendError(response, error);
  }
}

export async function deleteAddressHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireCustomer(request, response)) {
    return;
  }

  try {
    const address = await deleteAddress(request.auth!.userId, String(request.params.addressId));
    response.status(200).json({ address });
  } catch (error) {
    sendError(response, error);
  }
}

export async function setDefaultAddressHandler(
  request: AuthenticatedRequest,
  response: Response,
  _next: NextFunction
): Promise<void> {
  if (!requireCustomer(request, response)) {
    return;
  }

  try {
    const address = await setDefaultAddress(request.auth!.userId, String(request.params.addressId));
    response.status(200).json({ address });
  } catch (error) {
    sendError(response, error);
  }
}
