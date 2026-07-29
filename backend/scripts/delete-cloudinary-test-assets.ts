#!/usr/bin/env tsx
import { v2 as cloudinary } from "cloudinary";
import dotenv from "dotenv";
dotenv.config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME!,
  api_key: process.env.CLOUDINARY_API_KEY!,
  api_secret: process.env.CLOUDINARY_API_SECRET!,
  secure: true,
});

const assets: Array<{ publicId: string; resourceType: "image"; type: "authenticated" | "upload" }> = [
  {
    publicId: "veedufix/kyc/cms4sxavl0000trrg7od9zrlp/aadhaar/kyc-cms4sxavl0000trrg7od9zrlp-aadhaar-1785251965019",
    resourceType: "image",
    type: "authenticated",
  },
  {
    publicId: "veedufix/kyc/legacy/amqxak5ojfovva8cmpq5",
    resourceType: "image",
    type: "upload",
  },
];

async function main() {
  console.log("Deleting orphaned Cloudinary test assets...\n");
  for (const asset of assets) {
    try {
      const result = await cloudinary.uploader.destroy(asset.publicId, {
        resource_type: asset.resourceType,
        type: asset.type,
        invalidate: true,
      });
      console.log(`  ✅ ${asset.publicId}  →  result: ${result.result}`);
    } catch (err: unknown) {
      const msg =
        err instanceof Error
          ? err.message
          : err && typeof err === "object"
          ? (err as any).message ?? JSON.stringify(err)
          : String(err);
      console.log(`  ⚠️  ${asset.publicId}  →  ERROR: ${msg}`);
    }
  }
  console.log("\nDone.");
}

main().catch(console.error);
