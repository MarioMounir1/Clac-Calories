// ============================================================
//  src/controllers/profile.controller.ts
//  The Teneen — User Profile & TDEE endpoints
//  PUT  /api/v1/users/profile   — update physical profile + goals
//  GET  /api/v1/users/tdee      — calculate & return TDEE breakdown
// ============================================================

import { Request, Response } from "express";
import { z } from "zod";
import prisma from "../services/prisma.service";

// ── Validation Schema ────────────────────────────────────────

const UpdateProfileSchema = z.object({
  name:             z.string().min(2).max(100).optional(),
  age:              z.number().int().min(5).max(120).optional(),
  weightKg:         z.number().min(20).max(400).optional(),
  heightCm:         z.number().min(50).max(300).optional(),
  targetWeightKg:   z.number().min(20).max(400).optional(), // goal weight from onboarding
  gender:           z.enum(["male", "female"]).optional(),
  activityLevel:    z.enum(["sedentary", "lightly_active", "moderate", "very_active"]).optional(),
  goal:             z.enum(["lose", "maintain", "gain"]).optional(),
  dailyCalorieGoal: z.number().int().min(500).max(10000).optional(),
  dailyWaterGoalMl: z.number().int().min(500).max(10000).optional(),
  language:         z.enum(["en", "ar"]).optional(),
});

// ── TDEE Calculation Helpers ─────────────────────────────────

const ACTIVITY_MULTIPLIERS: Record<string, number> = {
  sedentary:      1.2,
  lightly_active: 1.375,
  moderate:       1.55,
  very_active:    1.725,
};

const GOAL_ADJUSTMENTS: Record<string, number> = {
  lose:     -500,  // deficit
  maintain:    0,
  gain:     +300,  // surplus
};

/**
 * Mifflin-St Jeor formula (most accurate, used by MyFitnessPal)
 * BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) ± gender_factor
 */
function calculateTDEE(
  weightKg: number,
  heightCm: number,
  age: number,
  gender: "male" | "female",
  activityLevel: string,
  goal: string,
): {
  bmr: number;
  tdee: number;
  recommendedCalories: number;
  recommendedProtein: number;
  recommendedCarbs: number;
  recommendedFats: number;
} {
  const genderFactor = gender === "male" ? 5 : -161;
  const bmr = Math.round(
    10 * weightKg + 6.25 * heightCm - 5 * age + genderFactor,
  );

  const multiplier = ACTIVITY_MULTIPLIERS[activityLevel] ?? 1.55;
  const tdee = Math.round(bmr * multiplier);

  const adjustment = GOAL_ADJUSTMENTS[goal] ?? 0;
  const recommendedCalories = Math.max(1200, tdee + adjustment);

  // Macro split: Protein 30% | Carbs 40% | Fat 30%
  const recommendedProtein = Math.round((recommendedCalories * 0.30) / 4);
  const recommendedCarbs   = Math.round((recommendedCalories * 0.40) / 4);
  const recommendedFats    = Math.round((recommendedCalories * 0.30) / 9);

  return {
    bmr,
    tdee,
    recommendedCalories,
    recommendedProtein,
    recommendedCarbs,
    recommendedFats,
  };
}

// ── PUT /api/v1/users/profile ────────────────────────────────

export async function updateProfile(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const parsed = UpdateProfileSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        error: "Validation failed",
        details: parsed.error.flatten().fieldErrors,
      });
      return;
    }

    const data = parsed.data;

    // Fetch current user to fill in missing TDEE fields
    const currentUser = await prisma.user.findUnique({ where: { id: userId } });
    if (!currentUser) {
      res.status(404).json({ error: "User not found" });
      return;
    }

    // Auto-recalculate goals if physical profile is complete
    let autoGoals: {
      dailyCalorieGoal?: number;
      proteinGoal?: number;
      carbsGoal?: number;
      fatsGoal?: number;
    } = {};

    const weightKg     = data.weightKg     ?? currentUser.weightKg;
    const heightCm     = data.heightCm     ?? currentUser.heightCm;
    const age          = data.age          ?? currentUser.age;
    const gender       = (data.gender      ?? currentUser.gender) as "male" | "female" | null;
    const activityLevel = data.activityLevel ?? currentUser.activityLevel;
    const goal         = data.goal         ?? currentUser.goal;

    if (weightKg && heightCm && age && gender) {
      // Only auto-calculate if user didn't override dailyCalorieGoal explicitly
      if (data.dailyCalorieGoal === undefined) {
        const tdee = calculateTDEE(weightKg, heightCm, age, gender, activityLevel, goal);
        autoGoals = {
          dailyCalorieGoal: tdee.recommendedCalories,
          proteinGoal:      tdee.recommendedProtein,
          carbsGoal:        tdee.recommendedCarbs,
          fatsGoal:         tdee.recommendedFats,
        };
      }
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(data.name             !== undefined && { name:             data.name }),
        ...(data.age              !== undefined && { age:              data.age }),
        ...(data.weightKg         !== undefined && { weightKg:         data.weightKg }),
        ...(data.heightCm         !== undefined && { heightCm:         data.heightCm }),
        ...(data.targetWeightKg   !== undefined && { targetWeightKg:   data.targetWeightKg }),
        ...(data.gender           !== undefined && { gender:           data.gender }),
        ...(data.activityLevel    !== undefined && { activityLevel:    data.activityLevel }),
        ...(data.goal             !== undefined && { goal:             data.goal }),
        ...(data.dailyCalorieGoal !== undefined && { dailyCalorieGoal: data.dailyCalorieGoal }),
        ...(data.dailyWaterGoalMl !== undefined && { dailyWaterGoalMl: data.dailyWaterGoalMl }),
        ...(data.language         !== undefined && { language:         data.language }),
        ...autoGoals,
      },
      select: {
        id:               true,
        name:             true,
        email:            true,
        age:              true,
        weightKg:         true,
        heightCm:         true,
        targetWeightKg:   true,
        gender:           true,
        activityLevel:    true,
        goal:             true,
        dailyCalorieGoal: true,
        proteinGoal:      true,
        carbsGoal:        true,
        fatsGoal:         true,
        dailyWaterGoalMl: true,
        language:         true,
        isPremium:        true,
      },
    });

    res.status(200).json({
      message: "Profile updated successfully",
      user: updatedUser,
      goalsAutoCalculated: Object.keys(autoGoals).length > 0,
    });
  } catch (error) {
    console.error("[profile] updateProfile error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}

// ── GET /api/v1/users/tdee ───────────────────────────────────

export async function getTdee(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      res.status(404).json({ error: "User not found" });
      return;
    }

    if (!user.weightKg || !user.heightCm || !user.age || !user.gender) {
      res.status(400).json({
        error: "Incomplete profile",
        message: "Please complete your profile (age, weight, height, gender) to calculate TDEE.",
        missingFields: [
          ...(!user.age      ? ["age"]      : []),
          ...(!user.weightKg ? ["weightKg"] : []),
          ...(!user.heightCm ? ["heightCm"] : []),
          ...(!user.gender   ? ["gender"]   : []),
        ],
      });
      return;
    }

    const tdee = calculateTDEE(
      user.weightKg,
      user.heightCm,
      user.age,
      user.gender as "male" | "female",
      user.activityLevel,
      user.goal,
    );

    res.status(200).json({
      bmr:            tdee.bmr,
      tdee:           tdee.tdee,
      activityLevel:  user.activityLevel,
      goal:           user.goal,
      recommendedCalories: tdee.recommendedCalories,
      macros: {
        protein: tdee.recommendedProtein,
        carbs:   tdee.recommendedCarbs,
        fats:    tdee.recommendedFats,
      },
      goalAdjustment: GOAL_ADJUSTMENTS[user.goal] ?? 0,
      formula:        "Mifflin-St Jeor",
    });
  } catch (error) {
    console.error("[profile] getTdee error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}
