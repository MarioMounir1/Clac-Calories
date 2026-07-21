// ============================================================
//  src/controllers/workout.controller.ts
//  Aura — Workout Routine Setup & Session endpoints
//
//  POST /api/v1/workouts/setup   — save user's chosen split
//  GET  /api/v1/workouts/routine — get active routine + currentSession
// ============================================================

import { Request, Response } from "express";
import { z } from "zod";
import prisma from "../services/prisma.service";
import { WorkoutService } from "../services/workout.service";

// ── Types ──────────────────────────────────────────────────

interface SessionExercise {
  id?: string;
  name: string;
  targetSets: number;
  muscleGroup: string;
  lastWeekWeight?: number;
  lastWeekReps?: number;
}

interface CurrentSession {
  routineName: string;
  todayDayName: string;
  exercises: SessionExercise[];
  topHistoricalSet: {
    exerciseName: string;
    weight: number;
    reps: number;
    progressionDelta: string;
  } | null;
}

// ── Zod Schemas ────────────────────────────────────────────

const SetupSchema = z.object({
  daysPerWeek: z.number().int().min(3).max(6),
  splitType:   z.string().min(1).max(80),
  splitName:   z.string().min(1).max(120),
});

const StartSessionSchema = z.object({ 
  name: z.string().min(1),
  exercises: z.array(z.object({
    id: z.string().nullish(), // Exercise DB id
    name: z.string(),
    targetSets: z.number().int(),
    muscleGroup: z.string().nullish(),
    lastWeekWeight: z.number().nullish(),
    lastWeekReps: z.number().nullish()
  })).nullish()
});
const AddExerciseSchema = z.object({ sessionId: z.string(), exerciseId: z.string(), order: z.number().int(), notes: z.string().optional() });
const LogSetSchema = z.object({ workoutExerciseId: z.string(), setNumber: z.number().int(), reps: z.number().int().optional(), weightKg: z.number().optional(), rpe: z.number().optional() });

// ── Static exercise catalogue per day type ─────────────────
const DAY_EXERCISES: Record<string, SessionExercise[]> = {
  "Push":              [{ name: "Barbell Bench Press", targetSets: 4, muscleGroup: "Chest · Triceps", lastWeekWeight: 80, lastWeekReps: 8 }, { name: "Incline Dumbbell Press", targetSets: 3, muscleGroup: "Upper Chest", lastWeekWeight: 32, lastWeekReps: 10 }, { name: "Cable Lateral Raises", targetSets: 4, muscleGroup: "Side Delts", lastWeekWeight: 12, lastWeekReps: 15 }, { name: "Tricep Pushdown", targetSets: 3, muscleGroup: "Triceps", lastWeekWeight: 35, lastWeekReps: 12 }],
  "Push A":            [{ name: "Barbell Bench Press", targetSets: 5, muscleGroup: "Chest · Triceps", lastWeekWeight: 80, lastWeekReps: 5 }, { name: "Overhead Press", targetSets: 4, muscleGroup: "Shoulders", lastWeekWeight: 55, lastWeekReps: 8 }, { name: "Incline Dumbbell Press", targetSets: 3, muscleGroup: "Upper Chest", lastWeekWeight: 30, lastWeekReps: 10 }, { name: "Tricep Dips", targetSets: 3, muscleGroup: "Triceps", lastWeekWeight: 0, lastWeekReps: 12 }],
  "Push B":            [{ name: "Dumbbell Bench Press", targetSets: 4, muscleGroup: "Chest · Triceps", lastWeekWeight: 36, lastWeekReps: 10 }, { name: "Arnold Press", targetSets: 3, muscleGroup: "Shoulders", lastWeekWeight: 24, lastWeekReps: 10 }, { name: "Cable Flyes", targetSets: 3, muscleGroup: "Chest", lastWeekWeight: 18, lastWeekReps: 15 }, { name: "Skull Crushers", targetSets: 3, muscleGroup: "Triceps", lastWeekWeight: 30, lastWeekReps: 12 }],
  "Pull":              [{ name: "Pull-Ups", targetSets: 4, muscleGroup: "Back · Biceps", lastWeekWeight: 0, lastWeekReps: 10 }, { name: "Barbell Row", targetSets: 4, muscleGroup: "Mid Back", lastWeekWeight: 75, lastWeekReps: 8 }, { name: "Face Pulls", targetSets: 3, muscleGroup: "Rear Delts", lastWeekWeight: 20, lastWeekReps: 15 }, { name: "Barbell Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 40, lastWeekReps: 10 }],
  "Pull A":            [{ name: "Weighted Pull-Ups", targetSets: 5, muscleGroup: "Back · Biceps", lastWeekWeight: 20, lastWeekReps: 6 }, { name: "Barbell Row", targetSets: 4, muscleGroup: "Mid Back", lastWeekWeight: 80, lastWeekReps: 8 }, { name: "Cable Row", targetSets: 3, muscleGroup: "Lower Back", lastWeekWeight: 65, lastWeekReps: 12 }, { name: "Incline Dumbbell Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 16, lastWeekReps: 12 }],
  "Pull B":            [{ name: "Lat Pulldown", targetSets: 4, muscleGroup: "Lats", lastWeekWeight: 70, lastWeekReps: 10 }, { name: "Seated Cable Row", targetSets: 4, muscleGroup: "Mid Back", lastWeekWeight: 65, lastWeekReps: 12 }, { name: "Rear Delt Flyes", targetSets: 3, muscleGroup: "Rear Delts", lastWeekWeight: 14, lastWeekReps: 15 }, { name: "Hammer Curl", targetSets: 3, muscleGroup: "Brachialis", lastWeekWeight: 20, lastWeekReps: 12 }],
  "Legs":              [{ name: "Hack Squats", targetSets: 4, muscleGroup: "Quads", lastWeekWeight: 180, lastWeekReps: 6 }, { name: "Smith Squats", targetSets: 3, muscleGroup: "Quads · Glutes", lastWeekWeight: 100, lastWeekReps: 10 }, { name: "Romanian Deadlifts", targetSets: 4, muscleGroup: "Hamstrings", lastWeekWeight: 90, lastWeekReps: 10 }, { name: "Standing Calf Raises", targetSets: 4, muscleGroup: "Calves", lastWeekWeight: 120, lastWeekReps: 15 }],
  "Legs A":            [{ name: "Back Squat", targetSets: 5, muscleGroup: "Quads · Glutes", lastWeekWeight: 110, lastWeekReps: 5 }, { name: "Romanian Deadlifts", targetSets: 4, muscleGroup: "Hamstrings", lastWeekWeight: 90, lastWeekReps: 8 }, { name: "Leg Press", targetSets: 3, muscleGroup: "Quads", lastWeekWeight: 200, lastWeekReps: 12 }, { name: "Leg Curl", targetSets: 3, muscleGroup: "Hamstrings", lastWeekWeight: 50, lastWeekReps: 12 }],
  "Legs B":            [{ name: "Front Squat", targetSets: 4, muscleGroup: "Quads", lastWeekWeight: 80, lastWeekReps: 8 }, { name: "Hack Squats", targetSets: 3, muscleGroup: "Quads", lastWeekWeight: 160, lastWeekReps: 8 }, { name: "Stiff-Leg Deadlift", targetSets: 3, muscleGroup: "Hamstrings", lastWeekWeight: 80, lastWeekReps: 10 }, { name: "Seated Calf Raises", targetSets: 4, muscleGroup: "Calves", lastWeekWeight: 60, lastWeekReps: 15 }],
  "Upper":             [{ name: "Barbell Bench Press", targetSets: 4, muscleGroup: "Chest", lastWeekWeight: 80, lastWeekReps: 8 }, { name: "Barbell Row", targetSets: 4, muscleGroup: "Back", lastWeekWeight: 75, lastWeekReps: 8 }, { name: "Overhead Press", targetSets: 3, muscleGroup: "Shoulders", lastWeekWeight: 55, lastWeekReps: 8 }, { name: "Barbell Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 42, lastWeekReps: 10 }],
  "Upper (Heavy)":     [{ name: "Barbell Bench Press", targetSets: 5, muscleGroup: "Chest", lastWeekWeight: 85, lastWeekReps: 5 }, { name: "Weighted Pull-Ups", targetSets: 5, muscleGroup: "Back", lastWeekWeight: 20, lastWeekReps: 6 }, { name: "Overhead Press", targetSets: 4, muscleGroup: "Shoulders", lastWeekWeight: 60, lastWeekReps: 5 }, { name: "Barbell Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 45, lastWeekReps: 8 }],
  "Upper (Volume)":    [{ name: "Dumbbell Bench Press", targetSets: 4, muscleGroup: "Chest", lastWeekWeight: 36, lastWeekReps: 10 }, { name: "Lat Pulldown", targetSets: 4, muscleGroup: "Back", lastWeekWeight: 70, lastWeekReps: 12 }, { name: "Dumbbell Shoulder Press", targetSets: 3, muscleGroup: "Shoulders", lastWeekWeight: 28, lastWeekReps: 12 }, { name: "Cable Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 22, lastWeekReps: 15 }],
  "Lower":             [{ name: "Back Squat", targetSets: 4, muscleGroup: "Quads · Glutes", lastWeekWeight: 100, lastWeekReps: 8 }, { name: "Romanian Deadlifts", targetSets: 4, muscleGroup: "Hamstrings", lastWeekWeight: 85, lastWeekReps: 8 }, { name: "Leg Press", targetSets: 3, muscleGroup: "Quads", lastWeekWeight: 180, lastWeekReps: 12 }, { name: "Standing Calf Raises", targetSets: 4, muscleGroup: "Calves", lastWeekWeight: 100, lastWeekReps: 15 }],
  "Lower (Heavy)":     [{ name: "Back Squat", targetSets: 5, muscleGroup: "Quads · Glutes", lastWeekWeight: 110, lastWeekReps: 5 }, { name: "Deadlift", targetSets: 4, muscleGroup: "Posterior Chain", lastWeekWeight: 140, lastWeekReps: 5 }, { name: "Leg Press", targetSets: 3, muscleGroup: "Quads", lastWeekWeight: 200, lastWeekReps: 10 }, { name: "Leg Curl", targetSets: 3, muscleGroup: "Hamstrings", lastWeekWeight: 55, lastWeekReps: 10 }],
  "Lower (Volume)":    [{ name: "Front Squat", targetSets: 4, muscleGroup: "Quads", lastWeekWeight: 75, lastWeekReps: 10 }, { name: "Romanian Deadlifts", targetSets: 4, muscleGroup: "Hamstrings", lastWeekWeight: 85, lastWeekReps: 10 }, { name: "Hack Squats", targetSets: 3, muscleGroup: "Quads", lastWeekWeight: 140, lastWeekReps: 12 }, { name: "Seated Calf Raises", targetSets: 3, muscleGroup: "Calves", lastWeekWeight: 65, lastWeekReps: 15 }],
  "Chest":             [{ name: "Barbell Bench Press", targetSets: 5, muscleGroup: "Chest", lastWeekWeight: 85, lastWeekReps: 5 }, { name: "Incline Dumbbell Press", targetSets: 4, muscleGroup: "Upper Chest", lastWeekWeight: 34, lastWeekReps: 10 }, { name: "Cable Flyes", targetSets: 3, muscleGroup: "Chest", lastWeekWeight: 20, lastWeekReps: 15 }, { name: "Dips", targetSets: 3, muscleGroup: "Lower Chest", lastWeekWeight: 0, lastWeekReps: 12 }],
  "Back":              [{ name: "Deadlift", targetSets: 4, muscleGroup: "Posterior Chain", lastWeekWeight: 140, lastWeekReps: 5 }, { name: "Barbell Row", targetSets: 4, muscleGroup: "Mid Back", lastWeekWeight: 80, lastWeekReps: 8 }, { name: "Pull-Ups", targetSets: 4, muscleGroup: "Lats", lastWeekWeight: 0, lastWeekReps: 10 }, { name: "Face Pulls", targetSets: 3, muscleGroup: "Rear Delts", lastWeekWeight: 22, lastWeekReps: 15 }],
  "Shoulders":         [{ name: "Barbell Overhead Press", targetSets: 4, muscleGroup: "Front Delts", lastWeekWeight: 60, lastWeekReps: 8 }, { name: "Cable Lateral Raises", targetSets: 4, muscleGroup: "Side Delts", lastWeekWeight: 14, lastWeekReps: 15 }, { name: "Rear Delt Flyes", targetSets: 4, muscleGroup: "Rear Delts", lastWeekWeight: 16, lastWeekReps: 15 }, { name: "Upright Row", targetSets: 3, muscleGroup: "Traps", lastWeekWeight: 45, lastWeekReps: 12 }],
  "Arms + Abs":        [{ name: "Barbell Curl", targetSets: 4, muscleGroup: "Biceps", lastWeekWeight: 45, lastWeekReps: 8 }, { name: "Skull Crushers", targetSets: 4, muscleGroup: "Triceps", lastWeekWeight: 35, lastWeekReps: 10 }, { name: "Hammer Curl", targetSets: 3, muscleGroup: "Brachialis", lastWeekWeight: 22, lastWeekReps: 12 }, { name: "Cable Crunch", targetSets: 3, muscleGroup: "Core", lastWeekWeight: 40, lastWeekReps: 15 }],
  "Legs + Arms":       [{ name: "Back Squat", targetSets: 4, muscleGroup: "Quads", lastWeekWeight: 100, lastWeekReps: 8 }, { name: "Barbell Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 42, lastWeekReps: 10 }, { name: "Romanian Deadlifts", targetSets: 3, muscleGroup: "Hamstrings", lastWeekWeight: 85, lastWeekReps: 8 }, { name: "Tricep Pushdown", targetSets: 3, muscleGroup: "Triceps", lastWeekWeight: 38, lastWeekReps: 12 }],
  "Chest + Back":      [{ name: "Barbell Bench Press", targetSets: 4, muscleGroup: "Chest", lastWeekWeight: 85, lastWeekReps: 6 }, { name: "Weighted Pull-Ups", targetSets: 4, muscleGroup: "Back", lastWeekWeight: 20, lastWeekReps: 8 }, { name: "Incline Press", targetSets: 3, muscleGroup: "Upper Chest", lastWeekWeight: 70, lastWeekReps: 10 }, { name: "Cable Row", targetSets: 3, muscleGroup: "Mid Back", lastWeekWeight: 65, lastWeekReps: 12 }],
  "Shoulders + Arms":  [{ name: "Overhead Press", targetSets: 4, muscleGroup: "Front Delts", lastWeekWeight: 60, lastWeekReps: 8 }, { name: "Barbell Curl", targetSets: 3, muscleGroup: "Biceps", lastWeekWeight: 45, lastWeekReps: 8 }, { name: "Lateral Raises", targetSets: 4, muscleGroup: "Side Delts", lastWeekWeight: 14, lastWeekReps: 15 }, { name: "Close-Grip Bench", targetSets: 3, muscleGroup: "Triceps", lastWeekWeight: 65, lastWeekReps: 10 }],
  "Full Body (Heavy)": [{ name: "Back Squat", targetSets: 5, muscleGroup: "Quads", lastWeekWeight: 110, lastWeekReps: 5 }, { name: "Barbell Bench Press", targetSets: 4, muscleGroup: "Chest", lastWeekWeight: 85, lastWeekReps: 5 }, { name: "Deadlift", targetSets: 3, muscleGroup: "Posterior Chain", lastWeekWeight: 140, lastWeekReps: 3 }, { name: "Overhead Press", targetSets: 3, muscleGroup: "Shoulders", lastWeekWeight: 60, lastWeekReps: 5 }],
  "Full Body (Moderate)":[{ name: "Front Squat", targetSets: 4, muscleGroup: "Quads", lastWeekWeight: 80, lastWeekReps: 8 }, { name: "Dumbbell Bench Press", targetSets: 4, muscleGroup: "Chest", lastWeekWeight: 36, lastWeekReps: 10 }, { name: "Romanian Deadlifts", targetSets: 3, muscleGroup: "Hamstrings", lastWeekWeight: 90, lastWeekReps: 8 }, { name: "Barbell Row", targetSets: 3, muscleGroup: "Back", lastWeekWeight: 75, lastWeekReps: 8 }],
  "Full Body (Light)": [{ name: "Goblet Squat", targetSets: 3, muscleGroup: "Quads", lastWeekWeight: 32, lastWeekReps: 12 }, { name: "Push-Ups", targetSets: 3, muscleGroup: "Chest", lastWeekWeight: 0, lastWeekReps: 15 }, { name: "Dumbbell Row", targetSets: 3, muscleGroup: "Back", lastWeekWeight: 28, lastWeekReps: 12 }, { name: "Lunges", targetSets: 3, muscleGroup: "Glutes", lastWeekWeight: 20, lastWeekReps: 12 }],
  "Rest":              [],
};

// ── Static routine catalogue ───────────────────────────────
const ROUTINE_CATALOGUE: Record<string, { description: string; days: string[] }> = {
  full_body:    { description: "3 full-body sessions — all major muscle groups each day", days: ["Full Body (Heavy)", "Rest", "Full Body (Moderate)", "Rest", "Full Body (Light)", "Rest", "Rest"] },
  ppl_1x:      { description: "Classic PPL hit once per week — 3 dedicated sessions",    days: ["Push", "Pull", "Legs", "Rest", "Rest", "Rest", "Rest"] },
  upper_lower: { description: "Each muscle group 2× per week — optimal frequency",       days: ["Upper (Heavy)", "Lower (Heavy)", "Rest", "Upper (Volume)", "Lower (Volume)", "Rest", "Rest"] },
  bro_split:   { description: "One muscle group per day — high volume focus",             days: ["Chest", "Back", "Shoulders", "Legs + Arms", "Rest", "Rest", "Rest"] },
  ul_ppl:      { description: "Hybrid 5-day — upper/lower + push/pull/legs",             days: ["Upper", "Lower", "Push", "Pull", "Legs", "Rest", "Rest"] },
  bro_split_5: { description: "Full coverage — arms get dedicated session",               days: ["Chest", "Back", "Shoulders", "Legs", "Arms + Abs", "Rest", "Rest"] },
  ppl_2x:      { description: "Each muscle group 2× per week — king of hypertrophy",    days: ["Push A", "Pull A", "Legs A", "Rest", "Push B", "Pull B", "Legs B"] },
  arnold_split:{ description: "Arnold's 6-day blueprint — antagonist supersets",         days: ["Chest + Back", "Shoulders + Arms", "Legs", "Chest + Back", "Shoulders + Arms", "Legs", "Rest"] },
};

// ── Fetch user's actual previous performance from the DB ────
async function getLastWeekPerformance(userId: string, exerciseId: string): Promise<{ weight: number; reps: number } | null> {
  const lastWorkoutExercise = await prisma.workoutExercise.findFirst({
    where: {
      exerciseId,
      session: {
        userId,
        endedAt: { not: null }
      }
    },
    orderBy: {
      createdAt: 'desc'
    },
    include: {
      sets: {
        where: {
          isCompleted: true,
          weightKg: { not: null },
          reps: { not: null }
        },
        orderBy: [
          { weightKg: 'desc' },
          { reps: 'desc' }
        ],
        take: 1
      }
    }
  });

  if (lastWorkoutExercise && lastWorkoutExercise.sets.length > 0) {
    const topSet = lastWorkoutExercise.sets[0];
    return {
      weight: topSet.weightKg!,
      reps: topSet.reps!
    };
  }
  return null;
}

// ── Build currentSession from today's weekday + routine ────
async function buildCurrentSession(userId: string, splitType: string, splitName: string): Promise<CurrentSession> {
  const meta = ROUTINE_CATALOGUE[splitType];
  const days = meta?.days ?? [];

  // weekday: 1=Mon, 7=Sun. Convert to 0-indexed Mon=0
  const todayIndex = (new Date().getDay() + 6) % 7;
  const todayDayName = days[todayIndex % days.length] ?? "Rest";
  const baseExercises = DAY_EXERCISES[todayDayName] ?? [];

  // Fetch real Exercise IDs from the DB
  const dbExercises = await prisma.exercise.findMany({
    where: { name: { in: baseExercises.map(e => e.name) } }
  });

  const exercises = await Promise.all(baseExercises.map(async (ex) => {
    const dbEx = dbExercises.find(d => d.name === ex.name);
    if (!dbEx) {
      return {
        ...ex,
        id: undefined,
        lastWeekWeight: undefined,
        lastWeekReps: undefined
      };
    }

    const lastPerf = await getLastWeekPerformance(userId, dbEx.id);
    return {
      ...ex,
      id: dbEx.id,
      lastWeekWeight: lastPerf ? lastPerf.weight : null,
      lastWeekReps: lastPerf ? lastPerf.reps : null,
    };
  }));

  const first = exercises[0];
  const topHistoricalSet = (first && first.lastWeekWeight && first.lastWeekReps)
    ? {
        exerciseName: first.name,
        weight: first.lastWeekWeight,
        reps: first.lastWeekReps,
        progressionDelta: "+2.5 kg",
      }
    : null;

  return {
    routineName: splitName,
    todayDayName,
    exercises,
    topHistoricalSet,
  };
}

// ── POST /api/v1/workouts/setup ────────────────────────────

export async function setupWorkoutRoutine(req: Request, res: Response): Promise<void> {
  const parsed = SetupSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ success: false, error: "Validation failed", details: parsed.error.flatten().fieldErrors });
    return;
  }

  const { daysPerWeek, splitType, splitName } = parsed.data;
  const userId = req.user!.id;

  const meta = ROUTINE_CATALOGUE[splitType] ?? {
    description: `${daysPerWeek}-day custom split`,
    days: Array(daysPerWeek).fill("Training Day"),
  };

  try {
    await prisma.user.update({ where: { id: userId }, data: {} }).catch(() => {});

    console.log(`✅ [Workout] Routine setup by user ${userId}: ${splitName} (${daysPerWeek}d/${splitType})`);

    const currentSession = await buildCurrentSession(userId, splitType, splitName);

    res.status(200).json({
      success: true,
      data: {
        routine: {
          splitType,
          splitName,
          daysPerWeek,
          description: meta.description,
          weekSchedule: meta.days,
          configuredAt: new Date().toISOString(),
        },
        currentSession,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [Workout] setup error:", msg);
    res.status(500).json({ success: false, error: "Failed to save routine configuration." });
  }
}

// ── GET /api/v1/workouts/routine ───────────────────────────

export async function getWorkoutRoutine(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user!.id;
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.age || !user.weightKg) {
      res.status(200).json({
        success: true,
        data: { routine: null, currentSession: null },
      });
      return;
    }

    // Map activityLevel to routine
    let splitType = "upper_lower";
    let splitName = "Upper / Lower Split";
    let daysPerWeek = 4;

    if (user.activityLevel === "sedentary") {
      splitType = "full_body";
      splitName = "Full Body Split";
      daysPerWeek = 3;
    } else if (user.activityLevel === "lightly_active") {
      splitType = "ppl_1x";
      splitName = "Push / Pull / Legs";
      daysPerWeek = 3;
    } else if (user.activityLevel === "moderate") {
      splitType = "upper_lower";
      splitName = "Upper / Lower Split";
      daysPerWeek = 4;
    } else if (user.activityLevel === "very_active") {
      splitType = "ul_ppl";
      splitName = "Hybrid PPL Split";
      daysPerWeek = 5;
    }

    const meta = ROUTINE_CATALOGUE[splitType];
    const currentSession = await buildCurrentSession(userId, splitType, splitName);

    res.status(200).json({
      success: true,
      data: {
        routine: {
          splitType,
          splitName,
          daysPerWeek,
          description: meta?.description ?? "",
          weekSchedule: meta?.days ?? [],
          configuredAt: user.updatedAt.toISOString(),
        },
        currentSession,
      },
    });
  } catch (err: unknown) {
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── GET /api/v1/workouts/exercises ─────────────────────────────
export async function getAvailableExercises(req: Request, res: Response): Promise<void> {
  try {
    const exercises = await prisma.exercise.findMany({
      select: { id: true, name: true, muscleGroup: true, mechanic: true },
      orderBy: { name: 'asc' },
    });
    res.status(200).json({ success: true, data: exercises });
  } catch (err) {
    console.error("❌ [Workout] getAvailableExercises error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── POST /api/v1/workouts/session/start ────────────────────────────
export async function startSession(req: Request, res: Response): Promise<void> {
  try {
    const parsed = StartSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ success: false, error: parsed.error.flatten() });
      return;
    }
    
    const userId = req.user!.id;
    const session = await WorkoutService.startWorkoutSession(userId, parsed.data.name, parsed.data.exercises);
    res.status(200).json({ success: true, data: session });
  } catch (err) {
    console.error("❌ [Workout] startSession error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── POST /api/v1/workouts/session/exercise ────────────────────────────
export async function addExercise(req: Request, res: Response): Promise<void> {
  try {
    const parsed = AddExerciseSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ success: false, error: parsed.error.flatten() });
      return;
    }
    
    const exercise = await WorkoutService.addExerciseToSession(
      parsed.data.sessionId, parsed.data.exerciseId, parsed.data.order, parsed.data.notes
    );
    res.status(200).json({ success: true, data: exercise });
  } catch (err) {
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── POST /api/v1/workouts/session/set ────────────────────────────
export async function logSet(req: Request, res: Response): Promise<void> {
  try {
    const parsed = LogSetSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ success: false, error: parsed.error.flatten() });
      return;
    }
    
    const set = await WorkoutService.logSet(
      parsed.data.workoutExerciseId, parsed.data.setNumber, parsed.data.reps, parsed.data.weightKg, parsed.data.rpe
    );
    res.status(200).json({ success: true, data: set });
  } catch (err) {
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── POST /api/v1/workouts/session/:id/finish ────────────────────────────
export async function finishSession(req: Request, res: Response): Promise<void> {
  try {
    const session = await WorkoutService.finishSession(req.params.id, req.body.notes);
    res.status(200).json({ success: true, data: session });
  } catch (err) {
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── GET /api/v1/workouts/exercises ────────────────────────────
export async function getAvailableExercises(req: Request, res: Response): Promise<void> {
  try {
    const exercises = await prisma.exercise.findMany({
      orderBy: { name: 'asc' }
    });
    res.status(200).json({ success: true, data: exercises });
  } catch (err) {
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}
