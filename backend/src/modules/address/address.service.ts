import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";

type SavedAddressInput = {
  label: string;
  addressLine1: string;
  addressLine2?: string | null;
  landmark?: string | null;
  city: string;
  pincode: string;
  lat: number;
  lng: number;
  isDefault?: boolean;
};

type SavedAddressUpdateInput = Pick<SavedAddressInput, "pincode"> &
  Partial<Omit<SavedAddressInput, "pincode">>;

export class SavedAddressNotFoundError extends Error {
  constructor(message = "Address not found") {
    super(message);
    this.name = "SavedAddressNotFoundError";
  }
}

// Follow-up: booking creation should accept an optional savedAddressId and reuse
// a SavedAddress record here instead of constructing a fresh address payload inline.

function normalizeOptionalText(value: string | undefined | null): string | null | undefined {
  if (value === undefined) {
    return undefined;
  }

  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

function toSavedAddressUpdatePayload(input: SavedAddressUpdateInput): Prisma.SavedAddressUpdateInput {
  return {
    ...(input.label !== undefined ? { label: input.label.trim() } : {}),
    ...(input.addressLine1 !== undefined ? { addressLine1: input.addressLine1.trim() } : {}),
    ...(input.addressLine2 !== undefined ? { addressLine2: normalizeOptionalText(input.addressLine2) } : {}),
    ...(input.landmark !== undefined ? { landmark: normalizeOptionalText(input.landmark) } : {}),
    ...(input.city !== undefined ? { city: input.city.trim() } : {}),
    ...(input.pincode !== undefined ? { pincode: input.pincode.trim() } : {}),
    ...(input.lat !== undefined ? { lat: input.lat } : {}),
    ...(input.lng !== undefined ? { lng: input.lng } : {}),
    ...(input.isDefault !== undefined ? { isDefault: input.isDefault } : {})
  };
}

async function getAddressForUserOrThrow(userId: string, addressId: string) {
  const address = await prisma.savedAddress.findFirst({
    where: {
      id: addressId,
      userId
    }
  });

  if (!address) {
    throw new SavedAddressNotFoundError();
  }

  return address;
}

export async function createAddress(userId: string, addressData: SavedAddressInput) {
  return prisma.$transaction(async (tx) => {
    if (addressData.isDefault) {
      await tx.savedAddress.updateMany({
        where: { userId },
        data: { isDefault: false }
      });
    }

    return tx.savedAddress.create({
      data: {
        userId,
        label: addressData.label.trim(),
        addressLine1: addressData.addressLine1.trim(),
        addressLine2: normalizeOptionalText(addressData.addressLine2),
        landmark: normalizeOptionalText(addressData.landmark),
        city: addressData.city.trim(),
        pincode: addressData.pincode.trim(),
        lat: addressData.lat,
        lng: addressData.lng,
        isDefault: addressData.isDefault ?? false
      }
    });
  });
}

export async function listAddresses(userId: string) {
  return prisma.savedAddress.findMany({
    where: { userId },
    orderBy: [{ isDefault: "desc" }, { createdAt: "desc" }]
  });
}

export async function updateAddress(userId: string, addressId: string, addressData: SavedAddressUpdateInput) {
  await getAddressForUserOrThrow(userId, addressId);

  return prisma.$transaction(async (tx) => {
    if (addressData.isDefault) {
      await tx.savedAddress.updateMany({
        where: {
          userId,
          NOT: { id: addressId }
        },
        data: { isDefault: false }
      });
    }

    return tx.savedAddress.update({
      where: { id: addressId },
      data: toSavedAddressUpdatePayload(addressData)
    });
  });
}

export async function deleteAddress(userId: string, addressId: string) {
  await getAddressForUserOrThrow(userId, addressId);

  return prisma.savedAddress.delete({
    where: { id: addressId }
  });
}

export async function setDefaultAddress(userId: string, addressId: string) {
  await getAddressForUserOrThrow(userId, addressId);

  return prisma.$transaction(async (tx) => {
    await tx.savedAddress.updateMany({
      where: {
        userId,
        NOT: { id: addressId }
      },
      data: { isDefault: false }
    });

    return tx.savedAddress.update({
      where: { id: addressId },
      data: { isDefault: true }
    });
  });
}
