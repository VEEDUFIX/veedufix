import { prisma } from "../../lib/prisma.js";
import { uploadBufferToCloudinary } from "../../lib/cloudinary.js";

type UploadedFile = Express.Multer.File;

type UploadedMediaResult = {
  url: string;
  publicId: string;
  bytes: number;
  format: string | undefined;
};

function buildPublicId(prefix: string, userId: string): string {
  return `${prefix}/${userId}/${Date.now()}`;
}

function cloudinaryFolder(prefix: string, userId: string): string {
  return `veedufix/${prefix}/${userId}`;
}

async function ensureWorkerProfile(userId: string) {
  const workerProfile = await prisma.workerProfile.findUnique({
    where: { userId }
  });

  if (!workerProfile) {
    throw new Error("Worker profile not found");
  }

  return workerProfile;
}

async function uploadMediaAsset(
  file: UploadedFile,
  options: {
    folder: string;
    publicId: string;
  }
): Promise<UploadedMediaResult> {
  const uploaded = await uploadBufferToCloudinary(file.buffer, {
    folder: options.folder,
    public_id: options.publicId,
    resource_type: "image",
    overwrite: true
  });

  return {
    url: uploaded.secure_url,
    publicId: uploaded.public_id,
    bytes: uploaded.bytes ?? file.size,
    format: uploaded.format
  };
}

export async function uploadAvatarImage(userId: string, file: UploadedFile) {
  const result = await uploadMediaAsset(file, {
    folder: cloudinaryFolder("avatars", userId),
    publicId: buildPublicId("avatar", userId)
  });

  const user = await prisma.user.update({
    where: { id: userId },
    data: { avatarUrl: result.url }
  });

  return {
    userId: user.id,
    avatarUrl: user.avatarUrl,
    asset: result
  };
}

export async function uploadWorkerPortfolioImage(
  userId: string,
  file: UploadedFile,
  caption?: string
) {
  const workerProfile = await ensureWorkerProfile(userId);
  const result = await uploadMediaAsset(file, {
    folder: cloudinaryFolder("portfolio", userId),
    publicId: buildPublicId("portfolio", userId)
  });

  const latestPhoto = await prisma.workerPortfolioPhoto.findFirst({
    where: { workerId: workerProfile.id },
    orderBy: { sortOrder: "desc" }
  });

  const photo = await prisma.workerPortfolioPhoto.create({
    data: {
      workerId: workerProfile.id,
      url: result.url,
      caption: caption?.trim() || null,
      sortOrder: (latestPhoto?.sortOrder ?? 0) + 1
    }
  });

  return {
    workerId: workerProfile.id,
    photo
  };
}

export async function uploadWorkerDocumentImage(
  userId: string,
  file: UploadedFile,
  type: string
) {
  const workerProfile = await ensureWorkerProfile(userId);
  const result = await uploadMediaAsset(file, {
    folder: cloudinaryFolder("documents", userId),
    publicId: buildPublicId("document", userId)
  });

  const document = await prisma.workerDocument.create({
    data: {
      workerId: workerProfile.id,
      type,
      url: result.url
    }
  });

  return {
    workerId: workerProfile.id,
    document
  };
}
