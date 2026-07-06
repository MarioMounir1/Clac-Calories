// ============================================================
//  src/controllers/meal.controller.ts
//  Calc-Calories — Multimodal Meal Analysis endpoint
//  POST /api/v1/meals/analyze
// ============================================================

import { Request, Response } from "express";
import { z } from "zod";
import { processUpload } from "../middleware/upload.middleware";
import { analyzeMeal } from "../services/ai.service";
import prisma from "../services/prisma.service";
import redis, { isRedisReady } from "../services/redis.service";

const CACHE_TTL_SECONDS = 60 * 60 * 24; // 24 hours

// ── Zod Validation Schema ──────────────────────────────────

const TextAnalyzeSchema = z.object({
  restaurantName: z
    .string()
    .max(200)
    .trim()
    .optional()
    .default("Homemade"),
  mealDescription: z
    .string()
    .min(2, "Meal description is required")
    .max(1000)
    .trim(),
});

// ── Cache Key Builder ──────────────────────────────────────

function buildCacheKey(restaurantName: string, mealDescription: string): string {
  const normalized = `${restaurantName.toLowerCase().trim()}::${mealDescription.toLowerCase().trim()}`;
  return `calc:meal:${Buffer.from(normalized).toString("base64").slice(0, 80)}`;
}

// ── Main Controller ────────────────────────────────────────

/**
 * POST /api/v1/meals/analyze
 *
 * Accepts either:
 *   - multipart/form-data with an "image" file field (screenshot analysis)
 *   - application/json with { restaurantName, mealDescription } (text analysis)
 *
 * Flow:
 *   1. Parse & validate input
 *   2. Check Redis cache (text-only)
 *   3. Call Gemini multimodal AI
 *   4. Save MealLog to PostgreSQL
 *   5. Update Redis cache
 *   6. Return structured response
 */
export async function analyzeMealHandler(
  req: Request,
  res: Response
): Promise<void> {
  const userId = req.user!.id;
  const contentType = req.headers["content-type"] ?? "";
  const isMultipart = contentType.includes("multipart/form-data");

  // ── Step 1: Handle file upload if multipart ──────────────
  if (isMultipart) {
    try {
      await processUpload(req, res);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Upload failed";
      res.status(400).json({ success: false, error: msg, code: "UPLOAD_ERROR" });
      return;
    }
  }

  // ── Step 2: Determine input mode & validate ──────────────
  const hasImage = !!req.file;

  if (!hasImage) {
    // Text mode: validate JSON body
    const parsed = TextAnalyzeSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: "Validation failed",
        details: parsed.error.flatten().fieldErrors,
        code: "VALIDATION_ERROR",
      });
      return;
    }
  } else {
    // Image mode: restaurantName is optional
    if (req.body.restaurantName && typeof req.body.restaurantName !== "string") {
      res.status(400).json({
        success: false,
        error: "restaurantName must be a string",
        code: "VALIDATION_ERROR",
      });
      return;
    }
  }

  const restaurantName: string = (req.body.restaurantName ?? "").trim();
  const mealDescription: string = (req.body.mealDescription ?? "").trim();

  // ── Step 3: Check Redis cache (text queries only) ────────
  const cacheKey =
    !hasImage && restaurantName && mealDescription
      ? buildCacheKey(restaurantName, mealDescription)
      : null;

  if (cacheKey && isRedisReady()) {
    try {
      const cached = await redis.get(cacheKey);
      if (cached) {
        const cachedResult = JSON.parse(cached);
        console.log(`✅ [Meal] Cache HIT: ${restaurantName} — ${mealDescription}`);

        // Still save to MealLog even for cache hits
        await logMealToDb(userId, cachedResult, "text", null, true);

        res.json({
          success: true,
          source: "cache",
          data: cachedResult,
        });
        return;
      }
    } catch (err: unknown) {
      // Cache miss or Redis error — proceed with AI call
      console.warn("⚠️  [Meal] Cache check failed:", err instanceof Error ? err.message : err);
    }
  }

  // ── Step 4: Call Gemini AI ───────────────────────────────
  let aiResult;
  try {
    if (hasImage) {
      const file = req.file!;
      aiResult = await analyzeMeal({
        type: "image",
        imageBuffer: file.buffer,
        mimeType: file.mimetype as "image/jpeg" | "image/png" | "image/webp",
        restaurantName: restaurantName || undefined,
      });
    } else {
      aiResult = await analyzeMeal({
        type: "text",
        restaurantName,
        mealDescription,
      });
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "AI analysis failed";
    console.error("❌ [Meal] Gemini error:", msg);

    const isQuota = msg.includes("429") || msg.toLowerCase().includes("quota");
    res.status(isQuota ? 429 : 502).json({
      success: false,
      error: isQuota
        ? "AI quota exceeded. Please try again later."
        : `AI analysis failed: ${msg}`,
      code: isQuota ? "QUOTA_EXCEEDED" : "AI_ERROR",
    });
    return;
  }

  // ── Step 5: Save MealLog to PostgreSQL ───────────────────
  let mealLog;
  try {
    mealLog = await logMealToDb(userId, aiResult, hasImage ? "image" : "text", aiResult, false);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "DB error";
    console.error("❌ [Meal] DB save error:", msg);
    // Don't fail the request — return AI result even if DB write fails
  }

  // ── Step 6: Update Redis cache (text only) ───────────────
  if (cacheKey && isRedisReady()) {
    try {
      await redis.setex(cacheKey, CACHE_TTL_SECONDS, JSON.stringify(aiResult));
    } catch {
      // Non-critical — cache write failure doesn't affect response
    }
  }

  console.log(
    `✅ [Meal] Analyzed (${hasImage ? "image" : "text"}): ${aiResult.mealName} — ${aiResult.calories} kcal`
  );

  res.status(201).json({
    success: true,
    source: "ai",
    data: {
      ...aiResult,
      logId: mealLog?.id,
      analyzedAt: new Date().toISOString(),
    },
  });
}

// ── Helper: Log meal to DB ─────────────────────────────────

async function logMealToDb(
  userId: string,
  result: {
    mealName: string;
    restaurantName: string;
    calories: number;
    protein: number;
    carbs: number;
    fats: number;
    ingredientsBreakdown: Array<{ ingredient: string; estimatedWeightGrams: number }>;
  },
  source: "text" | "image",
  rawAiResponse: object | null,
  fromCache: boolean
) {
  return prisma.mealLog.create({
    data: {
      userId,
      restaurantName: result.restaurantName,
      mealName: result.mealName,
      calories: result.calories,
      protein: result.protein,
      carbs: result.carbs,
      fats: result.fats,
      ingredientsBreakdown: result.ingredientsBreakdown as any,
      rawAiResponse: rawAiResponse as any,
      source,
    },
    select: { id: true },
  });
}
