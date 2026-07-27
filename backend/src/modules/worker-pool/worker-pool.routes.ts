import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { workerPoolQuerySchema } from "./worker-pool.schemas.js";
import { listWorkerPoolHandler } from "./worker-pool.controller.js";

export const workerPoolRouter = Router();

workerPoolRouter.use(requireAuth, requireRole("ADMIN"));
workerPoolRouter.get("/", validate(workerPoolQuerySchema), listWorkerPoolHandler);

