import { prisma } from "./prisma.js";
import { AppError } from "./app-error.js";
import { verifyAccessToken, type TokenPayload } from "./jwt.js";
import { createHash } from "crypto";

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export async function authenticateAccessToken(token: string): Promise<TokenPayload> {
  const payload = verifyAccessToken(token);
  const tokenHash = hashToken(token);

  const session = await prisma.authSession.findFirst({
    where: {
      id: payload.sessionId,
      userId: payload.sub,
      accessToken: tokenHash
    },
    select: {
      id: true,
      user: {
        select: {
          id: true,
          role: true
        }
      }
    }
  });

  if (!session || session.user.id !== payload.sub || session.user.role !== payload.role) {
    throw AppError.unauthorized("Session expired or revoked");
  }

  return payload;
}
