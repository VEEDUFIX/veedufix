import { type Request, type Response } from "express";
import { getOpsOverview } from "./ops.service.js";

export async function getOpsOverviewHandler(_request: Request, response: Response): Promise<void> {
  const result = await getOpsOverview();
  response.status(200).json(result);
}
