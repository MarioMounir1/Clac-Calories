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
import { generateWorkoutCoachNote, generateExerciseCoachNote, generateRoutineRecommendationNote } from "../services/coach.service";

// ── Types ──────────────────────────────────────────────────

interface SessionExercise {
  id?: string;
  name: string;
  targetSets: number;
  muscleGroup: string;
  lastWeekWeight?: number;
  lastWeekReps?: number;
  coachNote?: string;
}

interface CurrentSession {
  routineName: string;
  todayDayName: string;
  exercises: SessionExercise[];
  isSkipped?: boolean;
  isOverridden?: boolean;
  coachNote?: string;
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
async function buildCurrentSession(
  userId: string,
  splitType: string,
  splitName: string,
  dateStr?: string
): Promise<CurrentSession> {
  const meta = ROUTINE_CATALOGUE[splitType];
  const days = meta?.days ?? [];

  const targetDateStr = dateStr ?? new Date().toISOString().split("T")[0];

  // 1. Check for a date-specific override in SessionOverride table
  const override = await prisma.sessionOverride.findUnique({
    where: {
      userId_date: {
        userId,
        date: targetDateStr,
      },
    },
  });

  let todayDayName: string;
  let isOverridden = false;
  let isSkipped = false;

  if (override) {
    isOverridden = true;
    if (override.dayType === "skip") {
      isSkipped = true;
      todayDayName = "Skipped";
    } else {
      todayDayName = override.dayType;
    }
  } else {
    // weekday: 1=Mon, 7=Sun. Convert to 0-indexed Mon=0
    const targetDate = new Date(targetDateStr);
    const todayIndex = (targetDate.getDay() + 6) % 7;
    todayDayName = days[todayIndex % days.length] ?? "Rest";
  }

  // Handle explicit skipped state
  if (isSkipped) {
    return {
      routineName: splitName,
      todayDayName: "Skipped",
      exercises: [],
      isSkipped: true,
      isOverridden: true,
      coachNote: "Today is marked as skipped. Take the time to rest, recover, and stay hydrated.",
      topHistoricalSet: null,
    };
  }

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

  const exercisesWithCoachNotes = await Promise.all(
    exercises.map(async (ex) => {
      const coachNote = await generateExerciseCoachNote(ex);
      return {
        ...ex,
        coachNote,
      };
    })
  );

  const sessionCoachNote = await generateWorkoutCoachNote({
    splitName,
    todayDayName,
    exercises: exercisesWithCoachNotes,
  });

  const first = exercisesWithCoachNotes[0];
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
    exercises: exercisesWithCoachNotes,
    isSkipped: false,
    isOverridden,
    coachNote: sessionCoachNote,
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
    await prisma.user.update({
      where: { id: userId },
      data: {
        workoutDays: daysPerWeek,
        workoutSplitType: splitType,
        workoutSplitName: splitName,
      },
    });

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
    if (!user || !user.age || !user.weightKg || !user.workoutSplitType || !user.workoutDays) {
      res.status(200).json({
        success: true,
        data: { routine: null, currentSession: null },
      });
      return;
    }

    const splitType = user.workoutSplitType;
    const splitName = user.workoutSplitName ?? user.workoutSplitType;
    const daysPerWeek = user.workoutDays;

    const meta = ROUTINE_CATALOGUE[splitType];
    const currentSession = await buildCurrentSession(userId, splitType, splitName);

    // Compute real workout streak & weekly completion from DB
    const now = new Date();
    const startOfWeek = new Date(now);
    const dayOfWeek = (now.getDay() + 6) % 7; // Mon = 0, Sun = 6
    startOfWeek.setDate(now.getDate() - dayOfWeek);
    startOfWeek.setHours(0, 0, 0, 0);

    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 7);

    const startOfWeekStr = startOfWeek.toISOString().split("T")[0];
    const endOfWeekMinus1Str = new Date(endOfWeek.getTime() - 86400000).toISOString().split("T")[0];

    const [thisWeekSessions, weekOverrides] = await Promise.all([
      prisma.workoutSession.findMany({
        where: {
          userId,
          startedAt: {
            gte: startOfWeek,
            lt: endOfWeek,
          },
        },
        select: { startedAt: true },
      }),
      prisma.sessionOverride.findMany({
        where: {
          userId,
          date: {
            gte: startOfWeekStr,
            lte: endOfWeekMinus1Str,
          },
        },
      }),
    ]);

    const overrideMap = new Map(weekOverrides.map((o) => [o.date, o.dayType]));
    const completedDateStrs = new Set(
      thisWeekSessions.map((s) => new Date(s.startedAt).toISOString().split("T")[0])
    );

    const completedDaysThisWeek = [false, false, false, false, false, false, false];
    thisWeekSessions.forEach((session) => {
      const sessDay = (new Date(session.startedAt).getDay() + 6) % 7;
      if (sessDay >= 0 && sessDay < 7) {
        completedDaysThisWeek[sessDay] = true;
      }
    });

    const todayStr = now.toISOString().split("T")[0];
    const dayNamesShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const daysArr = meta?.days ?? [];

    const weekScheduleDetails = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(startOfWeek);
      d.setDate(startOfWeek.getDate() + i);
      const dateStr = d.toISOString().split("T")[0];

      const overrideType = overrideMap.get(dateStr);
      let dayType: string;
      let isOverridden = false;
      let isSkipped = false;

      if (overrideType) {
        isOverridden = true;
        if (overrideType === "skip") {
          isSkipped = true;
          dayType = "skip";
        } else {
          dayType = overrideType;
        }
      } else {
        dayType = daysArr[i % daysArr.length] ?? "Rest";
      }

      const isRest = dayType === "Rest";
      const isCompleted = completedDateStrs.has(dateStr);
      const isToday = dateStr === todayStr;
      const isPast = dateStr < todayStr;
      const isFuture = dateStr > todayStr;
      const isMissed = isPast && !isCompleted && !isRest && !isSkipped;

      return {
        dayName: dayNamesShort[i],
        dateStr,
        dayType,
        isRest,
        isSkipped,
        isOverridden,
        isCompleted,
        isMissed,
        isFuture,
        isToday,
      };
    });

    let streakDays = 0;
    const allSessions = await prisma.workoutSession.findMany({
      where: { userId },
      select: { startedAt: true },
      orderBy: { startedAt: 'desc' },
    });

    if (allSessions.length > 0) {
      const sessionDates = new Set(
        allSessions.map((s) => new Date(s.startedAt).toISOString().split('T')[0])
      );
      
      let checkDate = new Date();
      checkDate.setHours(0, 0, 0, 0);
      let checkStr = checkDate.toISOString().split('T')[0];

      if (!sessionDates.has(checkStr)) {
        checkDate.setDate(checkDate.getDate() - 1);
        checkStr = checkDate.toISOString().split('T')[0];
      }

      while (sessionDates.has(checkStr)) {
        streakDays++;
        checkDate.setDate(checkDate.getDate() - 1);
        checkStr = checkDate.toISOString().split('T')[0];
      }
    }

    res.status(200).json({
      success: true,
      data: {
        routine: {
          splitType,
          splitName,
          daysPerWeek,
          description: meta?.description ?? "",
          weekSchedule: weekScheduleDetails.map((d) => d.dayType),
          weekScheduleDetails,
          configuredAt: user.updatedAt.toISOString(),
        },
        currentSession,
        streakDays,
        completedDaysThisWeek,
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

// ── GET /api/v1/workouts/exercises/:id/alternatives ────────────────
export async function getExerciseAlternatives(req: Request, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const exercise = await prisma.exercise.findUnique({ where: { id } });
    if (!exercise) {
      res.status(404).json({ success: false, error: "Exercise not found" });
      return;
    }

    // 1. Check direct ExerciseAlternative entries
    const alternatives = await prisma.exerciseAlternative.findMany({
      where: { exerciseId: id },
      include: { alternative: true }
    });

    let data = alternatives.map(a => a.alternative);

    // 2. Fallback: If empty, fetch exercises with same muscle group (excluding itself)
    if (data.length === 0) {
      data = await prisma.exercise.findMany({
        where: {
          muscleGroup: exercise.muscleGroup,
          id: { not: id }
        },
        orderBy: { name: 'asc' },
        take: 10
      });
    }

    res.status(200).json({ success: true, data });
  } catch (err) {
    console.error("❌ [Workout] getExerciseAlternatives error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── POST /api/v1/workouts/session/swap ────────────────────────────
export async function swapSessionExercise(req: Request, res: Response): Promise<void> {
  const { workoutExerciseId, newExerciseId } = req.body;
  if (!workoutExerciseId || !newExerciseId) {
    res.status(400).json({ success: false, error: "Missing workoutExerciseId or newExerciseId" });
    return;
  }

  try {
    // 1. Perform Swap
    const updated = await prisma.workoutExercise.update({
      where: { id: workoutExerciseId },
      data: { exerciseId: newExerciseId },
      include: { exercise: true }
    });

    // 2. Clear any logged sets for this exercise log since the movement has changed
    await prisma.exerciseSet.deleteMany({
      where: { workoutExerciseId }
    });

    res.status(200).json({ success: true, data: updated });
  } catch (err) {
    console.error("❌ [Workout] swapSessionExercise error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── POST /api/v1/workouts/session/override ────────────────────────
const OverrideSessionSchema = z.object({
  date: z.string().optional(), // YYYY-MM-DD
  dayType: z.string().min(1).max(80),
});

export async function overrideSessionType(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      res.status(401).json({ success: false, error: "Unauthorized" });
      return;
    }

    const parsed = OverrideSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ success: false, error: "Invalid data", details: parsed.error.format() });
      return;
    }

    const targetDate = parsed.data.date ?? new Date().toISOString().split("T")[0];
    const dayType = parsed.data.dayType;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      res.status(404).json({ success: false, error: "User not found" });
      return;
    }

    let splitType = "upper_lower";
    let splitName = "Upper / Lower Split";
    if (user.activityLevel === "sedentary") {
      splitType = "full_body";
      splitName = "Full Body Split";
    } else if (user.activityLevel === "lightly_active") {
      splitType = "ppl_1x";
      splitName = "Push / Pull / Legs";
    } else if (user.activityLevel === "moderate") {
      splitType = "upper_lower";
      splitName = "Upper / Lower Split";
    } else if (user.activityLevel === "very_active") {
      splitType = "ul_ppl";
      splitName = "Hybrid PPL Split";
    }

    await prisma.sessionOverride.upsert({
      where: { userId_date: { userId, date: targetDate } },
      update: { dayType },
      create: { userId, date: targetDate, dayType },
    });

    const currentSession = await buildCurrentSession(userId, splitType, splitName, targetDate);

    res.status(200).json({
      success: true,
      message: "Session type overridden successfully",
      data: {
        date: targetDate,
        dayType,
        currentSession,
      },
    });
  } catch (error) {
    console.error("❌ [Workout] overrideSessionType error:", error);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── GET /api/v1/workouts/recommend ─────────────────────────────
export async function recommendWorkoutRoutine(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      res.status(401).json({ success: false, error: "Unauthorized" });
      return;
    }

    const rawDays = parseInt(req.query.days as string, 10);
    const days = isNaN(rawDays) ? 4 : Math.min(Math.max(rawDays, 3), 6);

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        trainingExperience: true,
        goal: true,
        activityLevel: true,
      },
    });

    const exp = (user?.trainingExperience ?? "new") as "new" | "consistent" | "experienced";
    const goal = (user?.goal ?? "maintain") as "lose" | "maintain" | "gain";

    interface SplitItem {
      name: string;
      splitType: string;
      tagline: string;
      breakdown: string[];
      reasonTag: string;
      rank: number;
    }

    let items: SplitItem[] = [];

    if (days === 3) {
      if (exp === "new") {
        items = [
          {
            name: "Full Body Split",
            splitType: "full_body",
            tagline: "3 full-body sessions — all major muscle groups each day",
            breakdown: ROUTINE_CATALOGUE["full_body"].days,
            reasonTag: "Best Fit: Optimal frequency for beginners",
            rank: 1,
          },
          {
            name: "Push / Pull / Legs",
            splitType: "ppl_1x",
            tagline: "Classic PPL hit once per week — 3 dedicated sessions",
            breakdown: ROUTINE_CATALOGUE["ppl_1x"].days,
            reasonTag: "Lower frequency per muscle group",
            rank: 2,
          },
        ];
      } else {
        items = [
          {
            name: "Push / Pull / Legs",
            splitType: "ppl_1x",
            tagline: "Classic PPL hit once per week — 3 dedicated sessions",
            breakdown: ROUTINE_CATALOGUE["ppl_1x"].days,
            reasonTag: "Best Fit: High per-session focus",
            rank: 1,
          },
          {
            name: "Full Body Split",
            splitType: "full_body",
            tagline: "3 full-body sessions — all major muscle groups each day",
            breakdown: ROUTINE_CATALOGUE["full_body"].days,
            reasonTag: "Higher per-session systemic fatigue",
            rank: 2,
          },
        ];
      }
    } else if (days === 4) {
      items = [
        {
          name: "Upper / Lower Split",
          splitType: "upper_lower",
          tagline: "Each muscle group 2× per week — optimal frequency",
          breakdown: ROUTINE_CATALOGUE["upper_lower"].days,
          reasonTag: "Best Fit: Balanced 2x weekly muscle frequency",
          rank: 1,
        },
        {
          name: "Bro Split (4-Day)",
          splitType: "bro_split",
          tagline: "One muscle group per day — high volume focus",
          breakdown: ROUTINE_CATALOGUE["bro_split"].days,
          reasonTag: "High volume — lower weekly frequency per muscle group",
          rank: 2,
        },
      ];
    } else if (days === 5) {
      items = [
        {
          name: "Hybrid PPL Split",
          splitType: "ul_ppl",
          tagline: "Hybrid 5-day — upper/lower + push/pull/legs",
          breakdown: ROUTINE_CATALOGUE["ul_ppl"].days,
          reasonTag: "Best Fit: Combines heavy strength & hypertrophy",
          rank: 1,
        },
        {
          name: "5-Day Bodypart Split",
          splitType: "bro_split_5",
          tagline: "Full coverage — arms get dedicated session",
          breakdown: ROUTINE_CATALOGUE["bro_split_5"].days,
          reasonTag: "High isolation volume — long recovery window",
          rank: 2,
        },
      ];
    } else if (days === 6) {
      if (exp === "experienced" && goal !== "lose") {
        items = [
          {
            name: "Arnold Split (6-Day)",
            splitType: "arnold_split",
            tagline: "Arnold's 6-day blueprint — antagonist supersets",
            breakdown: ROUTINE_CATALOGUE["arnold_split"].days,
            reasonTag: "Best Fit: Peak volume for experienced lifters",
            rank: 1,
          },
          {
            name: "Push / Pull / Legs (2x/wk)",
            splitType: "ppl_2x",
            tagline: "Each muscle group 2× per week — king of hypertrophy",
            breakdown: ROUTINE_CATALOGUE["ppl_2x"].days,
            reasonTag: "High frequency hypertrophy blueprint",
            rank: 2,
          },
        ];
      } else {
        items = [
          {
            name: "Push / Pull / Legs (2x/wk)",
            splitType: "ppl_2x",
            tagline: "Each muscle group 2× per week — king of hypertrophy",
            breakdown: ROUTINE_CATALOGUE["ppl_2x"].days,
            reasonTag: "Best Fit: Gold standard for 6-day hypertrophy & recovery",
            rank: 1,
          },
          {
            name: "Arnold Split (6-Day)",
            splitType: "arnold_split",
            tagline: "Arnold's 6-day blueprint — antagonist supersets",
            breakdown: ROUTINE_CATALOGUE["arnold_split"].days,
            reasonTag: "Extremely high volume — heavy recovery demand",
            rank: 2,
          },
        ];
      }
    }

    const top = items[0];
    const reasonNote = await generateRoutineRecommendationNote({
      days,
      trainingExperience: exp,
      goal,
      splitName: top.name,
    });

    const recommended = {
      ...top,
      reasonNote,
      reasonTag: "Best Fit for Your Profile",
    };

    const otherOptions = items.slice(1);

    res.status(200).json({
      success: true,
      data: {
        days,
        userProfile: { trainingExperience: exp, goal },
        recommended,
        otherOptions,
      },
    });
  } catch (error) {
    console.error("❌ [Workout] recommendWorkoutRoutine error:", error);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}
