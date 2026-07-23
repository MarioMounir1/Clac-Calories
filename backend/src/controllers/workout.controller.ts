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
import { generateWorkoutCoachNote, generateExerciseCoachNote, generateRoutineRecommendationNote, generateSwapSuggestionNote, generateWorkoutSummaryNote, generateOvertrainingNote, interpretSessionRequest, generateWeeklyRecapNote, generateIntentConfirmationNote } from "../services/coach.service";

// ── Types ──────────────────────────────────────────────────

interface SessionExercise {
  id?: string;
  name: string;
  targetSets: number;
  muscleGroup: string;
  lastWeekWeight?: number | null;
  lastWeekReps?: number | null;
  isPlateaued?: boolean;
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

// ── Fetch user's performance history for plateau detection ────
async function getRecentPerformanceTrend(
  userId: string,
  exerciseId: string,
  limit = 3
): Promise<{ history: { weight: number; reps: number }[]; isPlateaued: boolean }> {
  const recentExercises = await prisma.workoutExercise.findMany({
    where: {
      exerciseId,
      session: {
        userId,
        endedAt: { not: null },
      },
    },
    orderBy: {
      createdAt: "desc",
    },
    take: limit,
    include: {
      sets: {
        where: {
          isCompleted: true,
          weightKg: { not: null },
          reps: { not: null },
        },
        orderBy: [
          { weightKg: "desc" },
          { reps: "desc" },
        ],
        take: 1,
      },
    },
  });

  const history = recentExercises
    .filter((we) => we.sets.length > 0)
    .map((we) => ({
      weight: we.sets[0].weightKg!,
      reps: we.sets[0].reps!,
    }));

  let isPlateaued = false;
  if (history.length >= limit) {
    const first = history[0];
    isPlateaued = history.every((h) => h.weight <= first.weight && h.reps <= first.reps);
  }

  return { history, isPlateaued };
}

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

// ── Pure Data Fetch: fetchSessionData (0 Ollama calls) ────────
async function fetchSessionData(
  userId: string,
  splitType: string,
  splitName: string,
  dateStr?: string,
  configuredAt?: Date | null
): Promise<CurrentSession> {
  const meta = ROUTINE_CATALOGUE[splitType];
  const days = meta?.days ?? [];

  const targetDateStr = dateStr ?? new Date().toISOString().split("T")[0];

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
  } else if (configuredAt && days.length > 0) {
    const targetDate = new Date(targetDateStr + "T00:00:00Z");
    const configDateStr = configuredAt.toISOString().split("T")[0];
    const configDate = new Date(configDateStr + "T00:00:00Z");
    const diffDays = Math.max(0, Math.floor((targetDate.getTime() - configDate.getTime()) / 86400000));
    todayDayName = days[diffDays % days.length] ?? "Rest";
  } else {
    const targetDate = new Date(targetDateStr + "T00:00:00Z");
    const todayIndex = (targetDate.getDay() + 6) % 7;
    todayDayName = days[todayIndex % days.length] ?? "Rest";
  }

  if (isSkipped) {
    return {
      routineName: splitName,
      todayDayName: "Skipped",
      exercises: [],
      isSkipped: true,
      isOverridden: true,
      coachNote: "Today is marked as skipped. Focus on rest and recovery.",
      topHistoricalSet: null,
    };
  }

  const baseExercises = DAY_EXERCISES[todayDayName] ?? [];

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
        lastWeekReps: undefined,
        isPlateaued: false,
      };
    }

    const trend = await getRecentPerformanceTrend(userId, dbEx.id, 3);
    const lastPerf = trend.history[0] ?? null;
    return {
      ...ex,
      id: dbEx.id,
      lastWeekWeight: lastPerf ? lastPerf.weight : null,
      lastWeekReps: lastPerf ? lastPerf.reps : null,
      isPlateaued: trend.isPlateaued,
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
    isSkipped: false,
    isOverridden,
    coachNote: undefined,
    topHistoricalSet,
  };
}

// ── Attach Ollama Coach Notes (Only for full display rendering) ─
async function attachSessionCoachNotes(
  session: CurrentSession,
  splitName: string,
  streakDays?: number
): Promise<CurrentSession> {
  if (session.isSkipped) {
    const note = await generateWorkoutCoachNote({
      splitName,
      todayDayName: "Skipped",
      exercises: [],
      isSkipped: true,
      isOverridden: true,
      streakDays,
    });
    return { ...session, coachNote: note };
  }

  const exercisesWithCoachNotes = await Promise.all(
    session.exercises.map(async (ex) => {
      const coachNote = await generateExerciseCoachNote(ex);
      return {
        ...ex,
        coachNote,
      };
    })
  );

  const highFatigueRisk = (streakDays ?? 0) >= 3 && session.todayDayName !== "Rest" && !session.isSkipped;

  const sessionCoachNote = await generateWorkoutCoachNote({
    splitName,
    todayDayName: session.todayDayName,
    exercises: exercisesWithCoachNotes,
    isOverridden: session.isOverridden,
    isSkipped: false,
    streakDays,
    highFatigueRisk,
  });

  return {
    ...session,
    exercises: exercisesWithCoachNotes,
    coachNote: sessionCoachNote,
  };
}

// ── Build currentSession from configured date + routine ────
async function buildCurrentSession(
  userId: string,
  splitType: string,
  splitName: string,
  dateStr?: string,
  configuredAt?: Date | null,
  streakDays?: number
): Promise<CurrentSession> {
  const data = await fetchSessionData(userId, splitType, splitName, dateStr, configuredAt);
  return attachSessionCoachNotes(data, splitName, streakDays);
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
    const configuredAt = new Date();
    console.log(`⏳ [Workout] Setting up routine for user ${userId}: ${splitName} (${daysPerWeek}d/${splitType})`);
    await prisma.user.update({
      where: { id: userId },
      data: {
        workoutDays: daysPerWeek,
        workoutSplitType: splitType,
        workoutSplitName: splitName,
        workoutConfiguredAt: configuredAt,
      },
    });

    console.log(`✅ [Workout] Routine setup by user ${userId}: ${splitName} (${daysPerWeek}d/${splitType})`);

    const currentSession = await buildCurrentSession(userId, splitType, splitName, undefined, configuredAt);

    res.status(200).json({
      success: true,
      data: {
        routine: {
          splitType,
          splitName,
          daysPerWeek,
          description: meta.description,
          weekSchedule: meta.days,
          configuredAt: configuredAt.toISOString(),
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

    const targetDateStr = (req.query.date as string) || new Date().toISOString().split("T")[0];
    const splitType = user.workoutSplitType;
    const splitName = user.workoutSplitName ?? user.workoutSplitType;
    const daysPerWeek = user.workoutDays;
    const meta = ROUTINE_CATALOGUE[splitType];

    // Compute workout streak
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

    const currentSession = await buildCurrentSession(userId, splitType, splitName, targetDateStr, user.workoutConfiguredAt, streakDays);

    // Compute real weekly completion from DB
    const now = new Date(targetDateStr + "T12:00:00Z");
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

    const todayStr = targetDateStr;
    const dayNamesShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const daysArr = meta?.days ?? [];
    const configDateStr = user.workoutConfiguredAt ? user.workoutConfiguredAt.toISOString().split("T")[0] : null;

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
      } else if (configDateStr && user.workoutConfiguredAt) {
        const configDate = new Date(configDateStr + "T00:00:00Z");
        const curDate = new Date(dateStr + "T00:00:00Z");
        const diffDays = Math.floor((curDate.getTime() - configDate.getTime()) / 86400000);
        dayType = diffDays >= 0 ? (daysArr[diffDays % daysArr.length] ?? "Rest") : "Rest";
      } else {
        dayType = daysArr[i % daysArr.length] ?? "Rest";
      }

      const isBeforePlan = configDateStr != null && dateStr < configDateStr;
      const isRest = dayType === "Rest";
      const isCompleted = completedDateStrs.has(dateStr);
      const isToday = dateStr === todayStr;
      const isPast = dateStr < todayStr;
      const isFuture = dateStr > todayStr;
      const isMissed = isPast && !isBeforePlan && !isCompleted && !isRest && !isSkipped;

      return {
        dayName: dayNamesShort[i],
        dateStr,
        dayType,
        isBeforePlan,
        isRest,
        isSkipped,
        isOverridden,
        isCompleted,
        isMissed,
        isFuture,
        isToday,
      };
    });

    const uniqueTypes = Array.from(new Set(daysArr)).filter(t => t !== "Rest");
    const completedSessionNames = Array.from(completedDateStrs);
    const swapSuggestionNote = await generateSwapSuggestionNote({
      splitName,
      completedDaysThisWeek: completedSessionNames,
      availableOptions: uniqueTypes,
    });

    // Compute overtraining risk: compare actual consecutive completed days against split's max consecutive
    let splitMaxConsecutive = 0;
    let currentConsec = 0;
    for (const d of daysArr) {
      if (d !== "Rest") {
        currentConsec++;
        if (currentConsec > splitMaxConsecutive) splitMaxConsecutive = currentConsec;
      } else {
        currentConsec = 0;
      }
    }
    if (splitMaxConsecutive === 0) splitMaxConsecutive = 3;

    let actualConsecutive = 0;
    let tempConsecutive = 0;
    completedDaysThisWeek.forEach((done) => {
      if (done) {
        tempConsecutive++;
        if (tempConsecutive > actualConsecutive) actualConsecutive = tempConsecutive;
      } else {
        tempConsecutive = 0;
      }
    });

    const overtrainingRisk = actualConsecutive > splitMaxConsecutive || streakDays > (splitMaxConsecutive + 1);

    let overtrainingNote: string | null = null;
    if (overtrainingRisk) {
      overtrainingNote = await generateOvertrainingNote({
        consecutiveDays: Math.max(actualConsecutive, streakDays),
        splitMaxAllowed: splitMaxConsecutive,
      });
    }

    res.status(200).json({
      success: true,
      data: {
        routine: {
          splitType,
          splitName,
          daysPerWeek,
          description: meta.description,
          weekSchedule: meta.days,
          weekScheduleDetails,
          configuredAt: (user.workoutConfiguredAt ?? user.updatedAt).toISOString(),
          overtrainingRisk,
          overtrainingNote,
        },
        currentSession,
        streakDays,
        completedDaysThisWeek,
        swapSuggestionNote,
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
      select: { id: true, name: true, muscleGroup: true },
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
    const session = await WorkoutService.startWorkoutSession(userId, parsed.data.name, parsed.data.exercises ?? undefined);
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
    const sessionId = req.params.id;
    const session = await WorkoutService.finishSession(sessionId, req.body.notes);

    // Fetch full session details with completed exercises and sets
    const fullSession = await prisma.workoutSession.findUnique({
      where: { id: sessionId },
      include: {
        exercises: {
          include: {
            exercise: true,
            sets: true,
          },
        },
      },
    });

    let prsAchieved: string[] = [];
    let exercisesLogged = 0;
    let totalSetsCompleted = 0;

    if (fullSession) {
      for (const we of fullSession.exercises) {
        const completedSets = we.sets.filter((s) => s.isCompleted && s.weightKg != null && s.reps != null);
        if (completedSets.length > 0) {
          exercisesLogged++;
          totalSetsCompleted += completedSets.length;

          // Find top set in this session
          completedSets.sort((a, b) => (b.weightKg! * b.reps!) - (a.weightKg! * a.reps!));
          const sessionTopSet = completedSets[0];

          // Check historical best set before this session
          const previousBest = await prisma.exerciseSet.findFirst({
            where: {
              isCompleted: true,
              weightKg: { not: null },
              reps: { not: null },
              workoutExercise: {
                exerciseId: we.exerciseId,
                sessionId: { not: sessionId },
                session: { userId: fullSession.userId },
              },
            },
            orderBy: [{ weightKg: "desc" }, { reps: "desc" }],
          });

          if (previousBest && previousBest.weightKg != null && previousBest.reps != null) {
            if (
              sessionTopSet.weightKg! > previousBest.weightKg ||
              (sessionTopSet.weightKg! === previousBest.weightKg && sessionTopSet.reps! > previousBest.reps)
            ) {
              prsAchieved.push(`${we.exercise.name}: ${sessionTopSet.weightKg}kg × ${sessionTopSet.reps} reps`);
            }
          } else if (sessionTopSet.weightKg! > 0) {
            // First time logging this exercise
            prsAchieved.push(`${we.exercise.name}: ${sessionTopSet.weightKg}kg × ${sessionTopSet.reps} reps`);
          }
        }
      }
    }

    const summaryNote = await generateWorkoutSummaryNote({
      sessionName: session.name || "Workout",
      exercisesLogged,
      totalSetsCompleted,
      prsAchieved,
    });

    res.status(200).json({
      success: true,
      data: {
        ...session,
        summaryNote,
        prsAchieved,
      },
    });
  } catch (err) {
    console.error("❌ [Workout] finishSession error:", err);
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

// ── Interpret Natural Language Session Request ───────────────

export async function interpretWorkoutSessionRequest(req: Request, res: Response): Promise<void> {
  try {
    const { message } = req.body;
    if (!message || typeof message !== "string" || !message.trim()) {
      res.status(400).json({ success: false, error: "Message is required" });
      return;
    }

    const userId = req.user!.id;
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.workoutSplitType) {
      res.status(400).json({ success: false, error: "No active workout routine configuration found." });
      return;
    }

    const splitType = user.workoutSplitType;
    const splitName = user.workoutSplitName ?? user.workoutSplitType;
    const targetDateStr = new Date().toISOString().split("T")[0];

    const currentSession = await fetchSessionData(userId, splitType, splitName, targetDateStr, user.workoutConfiguredAt);
    const meta = ROUTINE_CATALOGUE[splitType];
    const availableDayTypes = meta?.days ?? [];

    const interpretation = await interpretSessionRequest(message.trim(), {
      splitName,
      availableDayTypes,
      todayDayName: currentSession.todayDayName,
      exercises: currentSession.exercises,
    });

    let actionExecuted = false;
    let swappedFrom: string | undefined;
    let swappedTo: string | undefined;

    if (interpretation.intent === "override_day" && interpretation.dayType) {
      const rawChosen = interpretation.dayType.trim();
      const chosenType = rawChosen.toLowerCase() === "skip" ? "skip" : rawChosen;
      await prisma.sessionOverride.upsert({
        where: { userId_date: { userId, date: targetDateStr } },
        update: { dayType: chosenType },
        create: { userId, date: targetDateStr, dayType: chosenType },
      });
      actionExecuted = true;
    } else if (interpretation.intent === "swap_exercise") {
      const queryName = (interpretation.exerciseName ?? "").toLowerCase();
      const targetEx = currentSession.exercises.find(
        (e) => e.name.toLowerCase().includes(queryName) || e.muscleGroup.toLowerCase().includes(queryName)
      ) ?? currentSession.exercises[0];

      if (targetEx && targetEx.id) {
        const alternatives = await prisma.exerciseAlternative.findMany({
          where: { exerciseId: targetEx.id },
          include: { alternative: true },
        });

        let alt = alternatives.length > 0 ? alternatives[0].alternative : null;
        if (!alt) {
          const fallbacks = await prisma.exercise.findMany({
            where: { muscleGroup: targetEx.muscleGroup, id: { not: targetEx.id } },
            take: 1,
          });
          if (fallbacks.length > 0) alt = fallbacks[0];
        }

        if (alt) {
          swappedFrom = targetEx.name;
          swappedTo = alt.name;
          const activeSession = await prisma.workoutSession.findFirst({
            where: { userId, endedAt: null },
            include: { exercises: true },
          });

          if (activeSession) {
            const we = activeSession.exercises.find((e) => e.exerciseId === targetEx.id) ?? activeSession.exercises[0];
            if (we) {
              await prisma.workoutExercise.update({
                where: { id: we.id },
                data: { exerciseId: alt.id },
              });
              await prisma.exerciseSet.deleteMany({ where: { workoutExerciseId: we.id } });
              actionExecuted = true;
            }
          } else {
            actionExecuted = true;
          }
        }
      }
    } else if (interpretation.intent === "lighter_intensity") {
      actionExecuted = true;
    }

    // Generate warm, casual coach confirmation line
    const confirmationMessage = await generateIntentConfirmationNote({
      intent: interpretation.intent,
      dayType: interpretation.dayType,
      exerciseSwappedFrom: swappedFrom,
      exerciseSwappedTo: swappedTo,
      userMessage: message.trim(),
    });

    // Fetch updated session data without triggering 10 exercise note calls
    const updatedSession = await fetchSessionData(userId, splitType, splitName, targetDateStr, user.workoutConfiguredAt);

    res.status(200).json({
      success: true,
      data: {
        intent: interpretation.intent,
        actionExecuted,
        confirmationMessage,
        currentSession: updatedSession,
      },
    });
  } catch (err) {
    console.error("❌ [Workout] interpretWorkoutSessionRequest error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}

// ── Weekly AI Recap ──────────────────────────────────────────

export async function getWeeklyRecap(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user!.id;
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.workoutSplitType) {
      res.status(200).json({
        success: true,
        data: { recapNote: "No active routine split found. Setup a routine to receive weekly recaps." },
      });
      return;
    }

    const now = new Date();
    const startOfWeek = new Date(now);
    const dayOfWeek = (now.getDay() + 6) % 7;
    startOfWeek.setDate(now.getDate() - dayOfWeek);
    startOfWeek.setHours(0, 0, 0, 0);

    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 7);

    const sessions = await prisma.workoutSession.findMany({
      where: {
        userId,
        startedAt: { gte: startOfWeek, lt: endOfWeek },
        endedAt: { not: null },
      },
      include: {
        exercises: {
          include: { exercise: true, sets: true },
        },
      },
    });

    const completedDaysCount = new Set(sessions.map((s) => new Date(s.startedAt).toISOString().split("T")[0])).size;
    const splitType = user.workoutSplitType;
    const splitName = user.workoutSplitName ?? user.workoutSplitType;
    const meta = ROUTINE_CATALOGUE[splitType];
    const daysArr = meta?.days ?? [];
    const scheduledTrainingDays = daysArr.filter((d) => d !== "Rest").length;

    const missedDaysCount = Math.max(0, Math.min(dayOfWeek + 1, scheduledTrainingDays) - completedDaysCount);
    const restDaysCount = (dayOfWeek + 1) - completedDaysCount;

    let prsAchieved: string[] = [];
    for (const session of sessions) {
      for (const we of session.exercises) {
        const completedSets = we.sets.filter((s) => s.isCompleted && s.weightKg != null && s.reps != null);
        if (completedSets.length > 0) {
          completedSets.sort((a, b) => (b.weightKg! * b.reps!) - (a.weightKg! * a.reps!));
          const topSet = completedSets[0];

          const previousBest = await prisma.exerciseSet.findFirst({
            where: {
              isCompleted: true,
              weightKg: { not: null },
              reps: { not: null },
              workoutExercise: {
                exerciseId: we.exerciseId,
                session: { userId, startedAt: { lt: startOfWeek } },
              },
            },
            orderBy: [{ weightKg: "desc" }, { reps: "desc" }],
          });

          if (previousBest && previousBest.weightKg != null) {
            if (topSet.weightKg! > previousBest.weightKg || (topSet.weightKg! === previousBest.weightKg && topSet.reps! > previousBest.reps!)) {
              prsAchieved.push(`${we.exercise.name}: ${topSet.weightKg}kg × ${topSet.reps} reps`);
            }
          }
        }
      }
    }

    let streakDays = 0;
    const allSessions = await prisma.workoutSession.findMany({
      where: { userId },
      select: { startedAt: true },
      orderBy: { startedAt: "desc" },
    });

    if (allSessions.length > 0) {
      const sessionDates = new Set(allSessions.map((s) => new Date(s.startedAt).toISOString().split("T")[0]));
      let checkDate = new Date();
      checkDate.setHours(0, 0, 0, 0);
      let checkStr = checkDate.toISOString().split("T")[0];
      if (!sessionDates.has(checkStr)) {
        checkDate.setDate(checkDate.getDate() - 1);
        checkStr = checkDate.toISOString().split("T")[0];
      }
      while (sessionDates.has(checkStr)) {
        streakDays++;
        checkDate.setDate(checkDate.getDate() - 1);
        checkStr = checkDate.toISOString().split("T")[0];
      }
    }

    const recapNote = await generateWeeklyRecapNote({
      splitName,
      completedDaysCount,
      missedDaysCount,
      restDaysCount,
      streakDays,
      prsAchieved: Array.from(new Set(prsAchieved)),
    });

    res.status(200).json({
      success: true,
      data: {
        splitName,
        completedDaysCount,
        missedDaysCount,
        restDaysCount,
        streakDays,
        prsAchieved: Array.from(new Set(prsAchieved)),
        recapNote,
      },
    });
  } catch (err) {
    console.error("❌ [Workout] getWeeklyRecap error:", err);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
}
