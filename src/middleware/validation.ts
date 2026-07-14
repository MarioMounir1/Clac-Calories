// ============================================================
//  src/middleware/validation.ts
//  Input validation and error handling
// ============================================================

import { Request, Response, NextFunction } from "express";
import { ErrorResponse, ErrorCode } from "../types";

export class AppError extends Error {
  constructor(
    public message: string,
    public code: ErrorCode,
    public statusCode: number = 400
  ) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

export function errorHandler(
  err: Error | AppError,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  console.error("🔴  Error:", err.message);

  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      success: false,
      error: err.message,
      code: err.code,
      timestamp: new Date(),
    } as ErrorResponse);
    return;
  }

  res.status(500).json({
    success: false,
    error: "Internal server error",
    code: ErrorCode.DATABASE_ERROR,
    timestamp: new Date(),
  } as ErrorResponse);
}

