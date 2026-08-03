import { Request, Response } from "express";
import { getAnalyticsTrends } from "./analytics.service.js";

export async function getAnalyticsTrendsHandler(request: Request, response: Response): Promise<void> {
  try {
    const days = request.query.days ? parseInt(request.query.days as string, 10) : 30;
    const result = await getAnalyticsTrends(isNaN(days) ? 30 : days);
    response.status(200).json(result);
  } catch (error) {
    request.log.error(error, "Failed to get analytics trends");
    response.status(500).json({ message: "Failed to load trends" });
  }
}
