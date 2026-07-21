// ============================================================
//  src/controllers/local-llama.controller.ts
//  Calc-Calories — Local Llama Image Scan Endpoint
//  POST /api/v1/meals/scan-local
//
//  Flow:
//    1. Accept multipart/form-data image upload
//    2. Convert image buffer → base64
//    3. Send to local Ollama vision model (llava / llama3.2-vision)
//    4. Parse structured macro response
//    5. Generate a contextual recommendation banner
//    6. Return LlamaMealResponse payload
// ============================================================

import { Request, Response } from "express";
import { processUpload } from "../middleware/upload.middleware";
import { OLLAMA_CONFIG } from "../config";
import prisma from "../services/prisma.service";

// ── Response Shape (matches Flutter LlamaMealResponse model) ─

export interface LlamaMealAnalysis {
  detectedFood: string;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
}

export interface LlamaRecommendation {
  triggerWarning: boolean;
  message: string;
}

export interface LlamaMealResponse {
  success: boolean;
  source: "local_llama_inference";
  mealAnalysis: LlamaMealAnalysis;
  llamaRecommendation: LlamaRecommendation;
}

// ── Ollama Vision Prompt ─────────────────────────────────────

const VISION_SYSTEM_PROMPT = `You are an expert nutritionist AI running locally. 
Analyze the food image provided and return ONLY a raw JSON object with NO markdown, NO explanation.

Required JSON structure:
{
  "detectedFood": "string — precise name of the meal/dish",
  "calories": integer,
  "protein": integer (grams),
  "carbs": integer (grams),
  "fats": integer (grams)
}

Rules:
- Be specific about the dish name (e.g. "Homemade Rice and Chicken Plate" not just "Chicken")
- Estimate realistic restaurant/home portions
- Never return prose or markdown — only the JSON object`;

// ── Recommendation Engine ────────────────────────────────────

function generateRecommendation(
  analysis: LlamaMealAnalysis,
  userProteinGoal = 150
): LlamaRecommendation {
  const { calories, protein, carbs, fats } = analysis;

  // High-carb, low-protein: protein deficit warning
  if (carbs > 70 && protein < 30) {
    const deficit = Math.round(userProteinGoal * 0.2);
    return {
      triggerWarning: true,
      message: `Llama Notice: This meal lacks sufficient protein for your daily goal. The carb load is high (${carbs}g). We recommend adding ${deficit}g of lean protein to your next meal.`,
    };
  }

  // Very high calories: caloric warning
  if (calories > 800) {
    return {
      triggerWarning: true,
      message: `Llama Notice: This is a high-calorie meal (${calories} kcal). Consider balancing your remaining meals today with lighter, protein-dense options to stay within your daily target.`,
    };
  }

  // High fat content
  if (fats > 30) {
    return {
      triggerWarning: true,
      message: `Llama Notice: This meal has elevated fat content (${fats}g). Pair your next meal with complex carbs and lean protein to balance your macro distribution.`,
    };
  }

  // High protein, clean meal
  if (protein >= 30 && calories < 600) {
    return {
      triggerWarning: false,
      message: `Llama says: Excellent macro balance! This meal supports muscle synthesis with ${protein}g of protein and a controlled caloric load. Keep it up.`,
    };
  }

  // Balanced meal
  return {
    triggerWarning: false,
    message: `Llama says: This looks like a balanced meal. Your macros are within healthy ranges — Calories: ${calories} kcal, Protein: ${protein}g, Carbs: ${carbs}g, Fats: ${fats}g.`,
  };
}

// ── Parse Ollama Text Response (handles dirty JSON) ──────────

function parseOllamaResponse(raw: string): LlamaMealAnalysis {
  let text = raw.trim();

  // Strip markdown fences if present
  text = text.replace(/```json/gi, "").replace(/```/g, "").trim();

  // Extract first JSON object block
  const jsonMatch = text.match(/\{[\s\S]*?\}/);
  if (!jsonMatch) {
    throw new Error(`No JSON object found in Ollama response: ${text.slice(0, 200)}`);
  }

  let parsed: any;
  try {
    parsed = JSON.parse(jsonMatch[0]);
  } catch {
    throw new Error(`Failed to parse Ollama JSON: ${jsonMatch[0].slice(0, 200)}`);
  }

  const detectedFood = String(parsed.detectedFood ?? parsed.dish_name ?? parsed.food ?? "Unknown Meal");
  const calories     = Math.round(Number(parsed.calories ?? 0));
  const protein      = Math.round(Number(parsed.protein ?? 0));
  const carbs        = Math.round(Number(parsed.carbs ?? parsed.carbohydrates ?? 0));
  const fats         = Math.round(Number(parsed.fats ?? parsed.fat ?? 0));

  if (calories === 0 && protein === 0 && carbs === 0 && fats === 0) {
    throw new Error("Ollama returned all-zero macros — likely failed to identify the food.");
  }

  return { detectedFood, calories, protein, carbs, fats };
}

// ── Main Handler ─────────────────────────────────────────────

/**
 * POST /api/v1/meals/scan-local
 *
 * Accepts: multipart/form-data with field "image"
 * Returns: LlamaMealResponse
 */
export async function scanLocalHandler(req: Request, res: Response): Promise<void> {
  // ── Step 1: Process multipart upload ────────────────────
  try {
    await processUpload(req, res);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Upload failed";
    res.status(400).json({
      success: false,
      source: "local_llama_inference",
      error: msg,
      code: "UPLOAD_ERROR",
    });
    return;
  }

  const file = req.file;
  if (!file) {
    res.status(400).json({
      success: false,
      source: "local_llama_inference",
      error: "No image provided. Please upload an image file in the 'image' field.",
      code: "MISSING_IMAGE",
    });
    return;
  }

  // ── Step 2: Validate AI Usage Limits ──────────────────────
  const scanType: "camera" | "gallery" = req.body.scanType === "camera" ? "camera" : "gallery";
  const userId = req.user!.id;
  const isPremium = req.user!.isPremium;

  try {
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setUTCHours(23, 59, 59, 999);

    const usageCount = await prisma.aiUsageLog.count({
      where: {
        userId,
        scanType,
        date: { gte: todayStart, lte: todayEnd },
      },
    });

    const limit = isPremium ? 7 : 2;
    if (usageCount >= limit) {
      res.status(isPremium ? 429 : 402).json({
        success: false,
        error: isPremium 
          ? `Premium limit reached. You can only use ${scanType} ${limit} times per day.`
          : `Free limit reached. Upgrade to Premium for more ${scanType} uses!`,
        code: "QUOTA_EXCEEDED",
      });
      return;
    }
  } catch (err: unknown) {
    console.error("❌ [LocalLlama] Quota check failed:", err);
    // Best-effort: allow if check fails to avoid blocking legitimate users due to DB errors
  }

  // ── Step 3: Convert image to base64 ──────────────────────
  const base64Image = file.buffer.toString("base64");
  const mimeType    = file.mimetype; // e.g. "image/jpeg"

  // ── Step 3: Call local Ollama vision model ───────────────
  const visionModel = process.env.OLLAMA_VISION_MODEL ?? "llava";
  console.log(`🦙 [LocalLlama] Analyzing image with model: ${visionModel} (${(file.size / 1024).toFixed(1)} KB)`);

  let rawContent: string;
  try {
    const ollamaRes = await fetch(`${OLLAMA_CONFIG.baseUrl}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: visionModel,
        prompt: VISION_SYSTEM_PROMPT,
        images: [base64Image],
        stream: false,
        options: {
          temperature: 0.1,
          num_predict: 256,
        },
      }),
      signal: AbortSignal.timeout(120_000), // 2-minute timeout for local inference
    });

    if (!ollamaRes.ok) {
      const errText = await ollamaRes.text().catch(() => "");
      throw new Error(`Ollama responded with ${ollamaRes.status}: ${errText.slice(0, 300)}`);
    }

    const ollamaData = (await ollamaRes.json()) as any;
    rawContent = ollamaData.response ?? ollamaData.message?.content ?? "";

    if (!rawContent) {
      throw new Error("Ollama returned an empty response body.");
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Ollama inference failed";
    console.error("❌ [LocalLlama] Ollama error:", msg);

    const isTimeout = msg.toLowerCase().includes("timeout") || msg.toLowerCase().includes("abort");
    res.status(isTimeout ? 504 : 502).json({
      success: false,
      source: "local_llama_inference",
      error: isTimeout
        ? "Local Llama model timed out. Ensure Ollama is running and the vision model is loaded."
        : `Local Llama inference failed: ${msg}`,
      code: isTimeout ? "LLAMA_TIMEOUT" : "LLAMA_ERROR",
    });
    return;
  }

  // ── Step 4: Parse structured macro data ─────────────────
  let mealAnalysis: LlamaMealAnalysis;
  try {
    mealAnalysis = parseOllamaResponse(rawContent);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Parse error";
    console.error("❌ [LocalLlama] Parse error:", msg);
    res.status(422).json({
      success: false,
      source: "local_llama_inference",
      error: `Could not extract macros from model output: ${msg}`,
      code: "PARSE_ERROR",
    });
    return;
  }

  // ── Step 5: Generate contextual recommendation ───────────
  const llamaRecommendation = generateRecommendation(mealAnalysis);

  // ── Step 6: Persist to MealLog (best-effort, non-blocking) ──
  try {
    await prisma.mealLog.create({
      data: {
        userId,
        mealName:      mealAnalysis.detectedFood,
        restaurantName: "Local Llama Scan",
        calories:      mealAnalysis.calories,
        protein:       mealAnalysis.protein,
        carbs:         mealAnalysis.carbs,
        fats:          mealAnalysis.fats,
        ingredientsBreakdown: [],
        rawAiResponse: { ...mealAnalysis, recommendation: llamaRecommendation } as any,
        source:        "image",
      },
      select: { id: true },
    });
    await prisma.aiUsageLog.create({ data: { userId, scanType, date: new Date() } });
  } catch (dbErr: unknown) {
    console.warn("⚠️  [LocalLlama] DB log failed (non-critical):", dbErr instanceof Error ? dbErr.message : dbErr);
  }

  console.log(
    `✅ [LocalLlama] ${mealAnalysis.detectedFood} — ${mealAnalysis.calories} kcal | P:${mealAnalysis.protein}g C:${mealAnalysis.carbs}g F:${mealAnalysis.fats}g`
  );

  // ── Step 7: Return structured response ──────────────────
  const response: LlamaMealResponse = {
    success: true,
    source:  "local_llama_inference",
    mealAnalysis,
    llamaRecommendation,
  };

  res.status(200).json(response);
}

// ── AI Usage Quota Endpoint ──────────────────────────────────

/**
 * GET /api/v1/meals/usage
 * Returns the current day's usage counts for camera and gallery scans.
 */
export async function getAiUsageHandler(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user!.id;
    
    // Get start and end of today in UTC
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setUTCHours(23, 59, 59, 999);

    const logs = await prisma.aiUsageLog.groupBy({
      by: ['scanType'],
      where: {
        userId,
        date: {
          gte: todayStart,
          lte: todayEnd,
        }
      },
      _count: {
        id: true,
      }
    });

    const usage = {
      camera: 0,
      gallery: 0,
    };

    logs.forEach(log => {
      if (log.scanType === 'camera') usage.camera = log._count.id;
      if (log.scanType === 'gallery') usage.gallery = log._count.id;
    });

    const isPremium = req.user?.isPremium ?? false;
    const limit = isPremium ? 9999 : 2;

    res.status(200).json({
      success: true,
      data: {
        usage,
        limits: {
          camera: limit,
          gallery: limit,
        },
        isPremium
      }
    });
  } catch (error: unknown) {
    console.error("❌ [AiUsage] Failed to fetch usage:", error);
    res.status(500).json({ success: false, error: "Failed to fetch usage limits" });
  }
}
