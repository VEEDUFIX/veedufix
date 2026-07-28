import { v2 as cloudinary, type UploadApiOptions, type UploadApiResponse } from "cloudinary";
import { env } from "../config/env.js";

let configured = false;

function ensureConfigured(): void {
  if (configured) {
    return;
  }

  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new Error("Cloudinary credentials are not configured");
  }

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true
  });

  configured = true;
}

export async function uploadBufferToCloudinary(
  buffer: Buffer,
  options: UploadApiOptions
): Promise<UploadApiResponse> {
  ensureConfigured();

  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(options, (error, result) => {
      if (error || !result) {
        reject(error ?? new Error("Cloudinary upload failed"));
        return;
      }

      resolve(result);
    });

    stream.end(buffer);
  });
}

/**
 * Generates a short-lived signed Cloudinary URL for a KYC document that was
 * uploaded with type:"authenticated".  The signed URL expires after
 * `expiresInSeconds` (default 5 minutes) and cannot be extended.
 *
 * @param publicId    The Cloudinary public_id stored in the database.
 * @param expiresInSeconds  TTL for the signed URL (default 300 s = 5 min).
 */
export function generateSignedUrl(publicId: string, expiresInSeconds = 300): string {
  ensureConfigured();

  const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;

  return cloudinary.url(publicId, {
    sign_url: true,
    expires_at: expiresAt,
    secure: true,
    type: "authenticated"
  });
}

/**
 * Parses the Cloudinary public_id out of a stored secure_url.
 *
 * IMPORTANT: This function is intentionally kept as a FALLBACK for the
 * one-time migration script only.  For all new uploads the public_id is
 * stored directly in the database and must be read from there instead of
 * being derived from the URL via string-parsing.
 *
 * Standard URL format (type:"upload" or type:"authenticated"):
 *   https://res.cloudinary.com/{cloud}/image/upload/v{version}/{publicId}.{ext}
 *   https://res.cloudinary.com/{cloud}/image/authenticated/s--{sig}--/v{ver}/{publicId}.{ext}
 *
 * Returns null if the URL cannot be parsed.
 */
export function extractPublicIdFromUrl(secureUrl: string): string | null {
  try {
    // Find the delivery-type segment (/upload/ or /authenticated/)
    const uploadIdx = secureUrl.indexOf("/upload/");
    const authIdx = secureUrl.indexOf("/authenticated/");

    const markerEnd = uploadIdx !== -1
      ? uploadIdx + "/upload/".length
      : authIdx !== -1
        ? authIdx + "/authenticated/".length
        : -1;

    if (markerEnd === -1) return null;

    let remainder = secureUrl.slice(markerEnd);

    // Strip optional signature block  s--xxxx--/
    remainder = remainder.replace(/^s--[^/]+--\//, "");

    // Strip optional version prefix  v1234567890/
    remainder = remainder.replace(/^v\d+\//, "");

    // Strip file extension
    const dotIdx = remainder.lastIndexOf(".");
    if (dotIdx !== -1) {
      remainder = remainder.slice(0, dotIdx);
    }

    return remainder.length > 0 ? remainder : null;
  } catch {
    return null;
  }
}

