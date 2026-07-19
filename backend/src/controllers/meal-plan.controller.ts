// ============================================================
//  src/controllers/meal-plan.controller.ts
//  The Teneen — Meal Plan endpoints
//  GET  /api/v1/meal-plans/today     — get today's plan entries
//  GET  /api/v1/meal-plans/week      — get full week plan
//  POST /api/v1/meal-plans/generate  — AI-generate a weekly plan
//  PUT  /api/v1/meal-plans/:id/eaten — mark a plan entry as eaten
// ============================================================

import { Request, Response } from "express";
import prisma from "../services/prisma.service";

// ── Helpers ───────────────────────────────────────────────────

function getWeekStart(date: Date = new Date()): Date {
  // Week starts on Saturday (Egyptian standard)
  const d = new Date(date);
  const day = d.getUTCDay(); // 0=Sun, 6=Sat
  const diff = day === 6 ? 0 : day + 1; // days back to Saturday
  d.setUTCDate(d.getUTCDate() - diff);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

function getTodayDayOfWeek(): number {
  return new Date().getUTCDay(); // 0=Sun … 6=Sat
}

const MEAL_TYPE_ORDER = ["breakfast", "lunch", "dinner", "snack"];
const DAY_LABELS: Record<number, { en: string; ar: string }> = {
  0: { en: "Sunday",    ar: "الأحد"     },
  1: { en: "Monday",    ar: "الاثنين"   },
  2: { en: "Tuesday",   ar: "الثلاثاء"  },
  3: { en: "Wednesday", ar: "الأربعاء"  },
  4: { en: "Thursday",  ar: "الخميس"    },
  5: { en: "Friday",    ar: "الجمعة"    },
  6: { en: "Saturday",  ar: "السبت"     },
};

// ── GET /api/v1/meal-plans/today ──────────────────────────────

export async function getTodayMealPlan(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ error: "Unauthorized" }); return; }

    const weekStart   = getWeekStart();
    const todayDow    = getTodayDayOfWeek();

    let entries = await prisma.mealPlan.findMany({
      where: { userId, weekStart, dayOfWeek: todayDow },
      include: { foodItem: true },
      orderBy: { mealType: "asc" },
    });

    // Auto-generate if no plan exists for the week
    if (entries.length === 0) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (user && user.dailyCalorieGoal) {
        await internalGenerateMealPlan(userId, user.dailyCalorieGoal, weekStart);
        entries = await prisma.mealPlan.findMany({
          where: { userId, weekStart, dayOfWeek: todayDow },
          include: { foodItem: true },
          orderBy: { mealType: "asc" },
        });
      }
    }

    // Sort by meal type order
    entries.sort(
      (a, b) =>
        MEAL_TYPE_ORDER.indexOf(a.mealType) - MEAL_TYPE_ORDER.indexOf(b.mealType),
    );

    const formatted = entries.map((e) => ({
      id:      e.id,
      mealType: e.mealType,
      servings: e.servings,
      isEaten:  e.isEaten,
      foodItem: {
        id:          e.foodItem.id,
        nameEn:      e.foodItem.nameEn,
        nameAr:      e.foodItem.nameAr,
        calories:    Math.round(e.foodItem.calories * e.servings * 10) / 10,
        protein:     Math.round(e.foodItem.protein  * e.servings * 10) / 10,
        carbs:       Math.round(e.foodItem.carbs    * e.servings * 10) / 10,
        fats:        Math.round(e.foodItem.fats     * e.servings * 10) / 10,
        servingSize: e.foodItem.servingSize,
        servingUnit: e.foodItem.servingUnit,
        category:    e.foodItem.category,
      },
    }));

    const totalCalories = formatted.reduce((s, e) => s + e.foodItem.calories, 0);

    res.status(200).json({
      dayOfWeek: todayDow,
      dayLabel:  DAY_LABELS[todayDow],
      entries:   formatted,
      totals: {
        calories: Math.round(totalCalories * 10) / 10,
        protein:  Math.round(formatted.reduce((s, e) => s + e.foodItem.protein, 0) * 10) / 10,
        carbs:    Math.round(formatted.reduce((s, e) => s + e.foodItem.carbs,   0) * 10) / 10,
        fats:     Math.round(formatted.reduce((s, e) => s + e.foodItem.fats,    0) * 10) / 10,
      },
      hasPlan: formatted.length > 0,
    });
  } catch (error) {
    console.error("[meal-plan] getTodayMealPlan error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}

// ── GET /api/v1/meal-plans/week ───────────────────────────────

export async function getWeekMealPlan(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ error: "Unauthorized" }); return; }

    const weekStart = getWeekStart();

    let entries = await prisma.mealPlan.findMany({
      where:   { userId, weekStart },
      include: { foodItem: true },
    });

    // Auto-generate if no plan exists for the week
    if (entries.length === 0) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (user && user.dailyCalorieGoal) {
        await internalGenerateMealPlan(userId, user.dailyCalorieGoal, weekStart);
        entries = await prisma.mealPlan.findMany({
          where: { userId, weekStart },
          include: { foodItem: true },
        });
      }
    }

    entries.sort((a, b) => (a.dayOfWeek - b.dayOfWeek) || (MEAL_TYPE_ORDER.indexOf(a.mealType) - MEAL_TYPE_ORDER.indexOf(b.mealType)));

    // Group by day
    const byDay: Record<number, any[]> = {};
    for (let d = 6; d <= 12; d++) {
      byDay[d % 7] = []; // Sat=6, Sun=0 … Fri=5
    }

    for (const e of entries) {
      const day = e.dayOfWeek;
      if (!byDay[day]) byDay[day] = [];
      byDay[day].push({
        id:       e.id,
        mealType: e.mealType,
        servings: e.servings,
        isEaten:  e.isEaten,
        foodItem: {
          id:          e.foodItem.id,
          nameEn:      e.foodItem.nameEn,
          nameAr:      e.foodItem.nameAr,
          calories:    Math.round(e.foodItem.calories * e.servings * 10) / 10,
          protein:     Math.round(e.foodItem.protein  * e.servings * 10) / 10,
          carbs:       Math.round(e.foodItem.carbs    * e.servings * 10) / 10,
          fats:        Math.round(e.foodItem.fats     * e.servings * 10) / 10,
          servingSize: e.foodItem.servingSize,
          servingUnit: e.foodItem.servingUnit,
          category:    e.foodItem.category,
        },
      });
    }

    // Sort each day's meals by meal type order
    for (const day of Object.keys(byDay)) {
      byDay[Number(day)].sort(
        (a: any, b: any) =>
          MEAL_TYPE_ORDER.indexOf(a.mealType) - MEAL_TYPE_ORDER.indexOf(b.mealType),
      );
    }

    const days = Object.entries(byDay).map(([dow, dayEntries]) => ({
      dayOfWeek: Number(dow),
      dayLabel:  DAY_LABELS[Number(dow)],
      isToday:   Number(dow) === getTodayDayOfWeek(),
      entries:   dayEntries,
      totalCalories: Math.round(
        dayEntries.reduce((s: number, e: any) => s + e.foodItem.calories, 0) * 10,
      ) / 10,
    }));

    res.status(200).json({
      weekStart: weekStart.toISOString().split("T")[0],
      hasPlan:   entries.length > 0,
      days,
    });
  } catch (error) {
    console.error("[meal-plan] getWeekMealPlan error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}

// ── POST /api/v1/meal-plans/generate ─────────────────────────

async function internalGenerateMealPlan(userId: string, targetCalories: number, weekStart: Date): Promise<number> {
  // Delete existing plan for this week
  await prisma.mealPlan.deleteMany({ where: { userId, weekStart } });

  // Fetch food items by category for planning
  const [breakfastItems, lunchItems, dinnerItems, snackItems] = await Promise.all([
    prisma.foodItem.findMany({ where: { category: "breakfast", isVerified: true }, take: 20 }),
    prisma.foodItem.findMany({ where: { category: { in: ["lunch", "protein"] }, isVerified: true }, take: 40 }),
    prisma.foodItem.findMany({ where: { category: { in: ["dinner", "grain"]  }, isVerified: true }, take: 30 }),
    prisma.foodItem.findMany({ where: { category: "snack", isVerified: true }, take: 20 }),
  ]);

  const rand = <T>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)];

  const planEntries: Array<{
    userId:    string;
    foodItemId: string;
    weekStart: Date;
    dayOfWeek: number;
    mealType:  string;
    servings:  number;
  }> = [];

  // Generate for all 7 days
  for (let dow = 0; dow < 7; dow++) {
    // Breakfast ~25% of calories
    if (breakfastItems.length > 0) {
      const item = rand(breakfastItems);
      const servings = Math.max(1, Math.round((targetCalories * 0.25) / item.calories));
      planEntries.push({ userId, foodItemId: item.id, weekStart, dayOfWeek: dow, mealType: "breakfast", servings });
    }

    // Lunch ~40% of calories
    if (lunchItems.length > 0) {
      const item = rand(lunchItems);
      const servings = Math.max(1, Math.round((targetCalories * 0.40) / item.calories));
      planEntries.push({ userId, foodItemId: item.id, weekStart, dayOfWeek: dow, mealType: "lunch", servings });
    }

    // Dinner ~25% of calories
    if (dinnerItems.length > 0) {
      const item = rand(dinnerItems);
      const servings = Math.max(1, Math.round((targetCalories * 0.25) / item.calories));
      planEntries.push({ userId, foodItemId: item.id, weekStart, dayOfWeek: dow, mealType: "dinner", servings });
    }

    // Snack ~10% of calories (not every day — 5/7 days)
    if (snackItems.length > 0 && dow % 2 !== 0) {
      const item = rand(snackItems);
      const servings = Math.max(1, Math.round((targetCalories * 0.10) / item.calories));
      planEntries.push({ userId, foodItemId: item.id, weekStart, dayOfWeek: dow, mealType: "snack", servings });
    }
  }

  await prisma.mealPlan.createMany({ data: planEntries });
  return planEntries.length;
}

export async function generateMealPlan(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ error: "Unauthorized" }); return; }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) { res.status(404).json({ error: "User not found" }); return; }

    const weekStart = getWeekStart();
    const entriesCount = await internalGenerateMealPlan(userId, user.dailyCalorieGoal || 2000, weekStart);

    res.status(201).json({
      message:    "Weekly meal plan generated successfully",
      weekStart:  weekStart.toISOString().split("T")[0],
      entriesCount,
      targetCaloriesPerDay: user.dailyCalorieGoal || 2000,
    });
  } catch (error) {
    console.error("[meal-plan] generateMealPlan error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}

// ── PUT /api/v1/meal-plans/:id/eaten ─────────────────────────

export async function markAsEaten(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) { res.status(401).json({ error: "Unauthorized" }); return; }

    const { id } = req.params;
    const isEaten = req.body.isEaten !== false; // defaults to true

    const entry = await prisma.mealPlan.findUnique({ where: { id } });
    if (!entry) { res.status(404).json({ error: "Meal plan entry not found" }); return; }
    if (entry.userId !== userId) { res.status(403).json({ error: "Forbidden" }); return; }

    const updated = await prisma.mealPlan.update({
      where: { id },
      data:  { isEaten },
    });

    res.status(200).json({
      message:  isEaten ? "Marked as eaten" : "Marked as not eaten",
      id:       updated.id,
      isEaten:  updated.isEaten,
    });
  } catch (error) {
    console.error("[meal-plan] markAsEaten error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}
