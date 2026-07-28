import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import {
  addSkillSchema,
  adminDocAadhaarParamsSchema,
  adminDocSkillParamsSchema,
  adminProfileParamsSchema,
  adminWorkerHistoryParamsSchema,
  adminWorkersQuerySchema,
  onboardingStatusSchema,
  pendingReviewQuerySchema,
  rejectProfileSchema,
  reinstateProfileSchema,
  submitForReviewSchema,
  suspendProfileSchema,
  updateProfileSchema,
  uploadDocumentSchema,
  workerDocAadhaarSchema,
  workerDocSkillParamsSchema
} from "./worker-onboarding.schemas.js";
import {
  addSkillHandler,
  approveWorkerHandler,
  getAdminAadhaarDocHandler,
  getAdminSkillCertDocHandler,
  getOwnAadhaarDocHandler,
  getOwnSkillCertDocHandler,
  getStatusHandler,
  getWorkerDirectoryHandler,
  getWorkerHistoryHandler,
  pendingReviewHandler,
  rejectWorkerHandler,
  reinstateWorkerHandler,
  submitForReviewHandler,
  suspendWorkerHandler,
  updateProfileHandler,
  uploadDocumentHandler
} from "./worker-onboarding.controller.js";

export const workerOnboardingRouter = Router();
export const adminWorkerReviewRouter = Router();
export const adminWorkerDirectoryRouter = Router();

workerOnboardingRouter.use(requireAuth, requireRole("WORKER"));
workerOnboardingRouter.post("/profile", validate(updateProfileSchema), updateProfileHandler);
workerOnboardingRouter.post("/documents", validate(uploadDocumentSchema), uploadDocumentHandler);
workerOnboardingRouter.post("/skills", validate(addSkillSchema), addSkillHandler);
workerOnboardingRouter.post("/submit", validate(submitForReviewSchema), submitForReviewHandler);
workerOnboardingRouter.get("/status", validate(onboardingStatusSchema), getStatusHandler);
// KYC document access — worker retrieves their own documents via signed URLs
workerOnboardingRouter.get("/documents/aadhaar", validate(workerDocAadhaarSchema), getOwnAadhaarDocHandler);
workerOnboardingRouter.get("/documents/skills/:skillId/certification", validate(workerDocSkillParamsSchema), getOwnSkillCertDocHandler);

adminWorkerReviewRouter.use(requireAuth, requireRole("ADMIN"));
adminWorkerReviewRouter.get("/pending", validate(pendingReviewQuerySchema), pendingReviewHandler);
adminWorkerReviewRouter.post("/:profileId/approve", validate(adminProfileParamsSchema), approveWorkerHandler);
adminWorkerReviewRouter.post("/:profileId/reject", validate(rejectProfileSchema), rejectWorkerHandler);
adminWorkerReviewRouter.post("/:profileId/suspend", validate(suspendProfileSchema), suspendWorkerHandler);
adminWorkerReviewRouter.post("/:profileId/reinstate", validate(reinstateProfileSchema), reinstateWorkerHandler);
// KYC document access — admin retrieves any worker's documents via signed URLs
adminWorkerReviewRouter.get("/:profileId/documents/aadhaar", validate(adminDocAadhaarParamsSchema), getAdminAadhaarDocHandler);
adminWorkerReviewRouter.get("/:profileId/documents/skills/:skillId/certification", validate(adminDocSkillParamsSchema), getAdminSkillCertDocHandler);

adminWorkerDirectoryRouter.use(requireAuth, requireRole("ADMIN"));
adminWorkerDirectoryRouter.get("/", validate(adminWorkersQuerySchema), getWorkerDirectoryHandler);
adminWorkerDirectoryRouter.get("/:profileId/history", validate(adminWorkerHistoryParamsSchema), getWorkerHistoryHandler);

