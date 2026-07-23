// ============================================================
//  src/services/coach.service.ts
//  Aura — Local Ollama AI Personal Coach Service
// ============================================================

import { OLLAMA_CONFIG } from "../config";

interface ExerciseInput {
  name: string;
  targetSets: number;
  lastWeekWeight?: number | null;
  lastWeekReps?: number | null;
}

interface WorkoutSessionInput {
  splitName: string;
  todayDayName: string;
  exercises: ExerciseInput[];
  isOverridden?: boolean;
  isSkipped?: boolean;
}

interface WeightTrendInput {
  totalDelta?: number;
  minWeight?: number;
  maxWeight?: number;
  avgWeight?: number;
  trend?: "losing" | "gaining" | "stable";
  goal?: string;
}

// ── Helper: Ollama Chat Call with Timeout & Fallback ───────

async function callOllamaChat(systemPrompt: string, userPrompt: string, fallback: string): Promise<string> {
  const provider = process.env.AI_PROVIDER ?? "ollama";
  if (provider === "none") {
    return fallback;
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 3500); // 3.5s safety cap

  try {
    const response = await fetch(`${OLLAMA_CONFIG.baseUrl}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        model: OLLAMA_CONFIG.model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        stream: false,
        options: {
          temperature: OLLAMA_CONFIG.temperature ?? 0.7,
          num_predict: 80, // Cap output token count for fast UI captions
        },
      }),
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      return fallback;
    }

    const data = (await response.json()) as any;
    const content = data.message?.content?.trim();

    if (!content) {
      return fallback;
    }

    // Strip markdown formatting, quotes, or newlines
    const cleaned = content.replace(/```[a-z]*|```/g, "").replace(/^["']|["']$/g, "").replace(/\s+/g, " ").trim();
    return cleaned || fallback;
  } catch (err) {
    clearTimeout(timeoutId);
    return fallback;
  }
}

// ── 1. Workout Session Coach Note ────────────────────────────

export async function generateWorkoutCoachNote(session: WorkoutSessionInput): Promise<string> {
  if (session.isSkipped) {
    const systemPrompt = `You are an encouraging strength coach. Produce 1 short sentence (maximum 25 words) acknowledging that the user marked today's workout as skipped. Be supportive and emphasize recovery and resuming next session. No markdown, no quotes.`;
    const userPrompt = `User skipped today's ${session.todayDayName} session. Give a brief supportive note.`;
    const fallback = `Marked as skipped — no problem, we'll pick right back up next session. Focus on rest and recovery today.`;
    return callOllamaChat(systemPrompt, userPrompt, fallback);
  }

  if (session.isOverridden) {
    const systemPrompt = `You are an expert strength coach. The user manually swapped today's session to ${session.todayDayName}. Produce 1-2 short sentences (maximum 30 words) acknowledging the swap and advising them to listen to their body and adjust recovery. No markdown, no quotes.`;
    const userPrompt = `User swapped today's session to ${session.todayDayName} on routine ${session.splitName}. Give a short coach tip acknowledging the swap.`;
    const fallback = `You swapped in ${session.todayDayName} today — make sure you are adequately recovered, and listen to your body throughout the session.`;
    return callOllamaChat(systemPrompt, userPrompt, fallback);
  }

  if (!session.exercises || session.exercises.length === 0) {
    return "Today is a dedicated rest day. Focus on hydration, mobility, and high-quality recovery.";
  }

  const exListStr = session.exercises
    .map((e) => `${e.name} (${e.lastWeekWeight ? `${e.lastWeekWeight}kg × ${e.lastWeekReps}` : "no history"})`)
    .join(", ");

  const systemPrompt = `You are an elite, encouraging strength coach. Produce 1-2 short, plain-language sentences max (maximum 35 words total). Explain what to focus on for today's session and why exercise sequence matters. Do NOT use markdown, bullet points, or quotes. Speak directly to the lifter.`;
  const userPrompt = `Routine: ${session.splitName} - ${session.todayDayName}. Exercises today: ${exListStr}. Give a short 1-2 sentence coach tip.`;

  const fallback = `Focus on clean execution today. Prioritize your heavy compound lifts first before moving to accessory movements.`;
  return callOllamaChat(systemPrompt, userPrompt, fallback);
}

// ── 2. Swap Suggestion Coach Note ────────────────────────────

interface SwapSuggestionInput {
  splitName: string;
  completedDaysThisWeek: string[];
  availableOptions: string[];
}

export async function generateSwapSuggestionNote(input: SwapSuggestionInput): Promise<string> {
  const systemPrompt = `You are a smart strength coach offering a quick 1-sentence recommendation for a workout session swap. Produce exactly ONE short sentence (maximum 22 words). No markdown, no quotes.`;
  const userPrompt = `Routine: ${input.splitName}. Sessions completed this week: ${input.completedDaysThisWeek.join(", ") || "none"}. Available swap options: ${input.availableOptions.join(", ")}. Recommend the single best option to swap today.`;

  const recommendedOption = input.availableOptions[0] ?? "Legs";
  const fallback = input.completedDaysThisWeek.length > 0
    ? `Given your recent sessions this week, ${recommendedOption} is likely your best swap choice today.`
    : `Selecting ${recommendedOption} keeps your training balanced and recovery on track today.`;

  return callOllamaChat(systemPrompt, userPrompt, fallback);
}

// ── 2. Exercise Specific Coach Note ──────────────────────────

export async function generateExerciseCoachNote(exercise: ExerciseInput): Promise<string> {
  const hasHistory = exercise.lastWeekWeight != null && exercise.lastWeekWeight > 0;
  const historyText = hasHistory
    ? `Last performance: ${exercise.lastWeekWeight}kg × ${exercise.lastWeekReps} reps.`
    : "No previous history recorded.";

  const systemPrompt = `You are a fitness coach. Produce exactly ONE short sentence (maximum 20 words) explaining what to aim for on this exercise today. No markdown, no quotes.`;
  const userPrompt = `Exercise: ${exercise.name}. ${historyText} Give one concise tip.`;

  const fallback = hasHistory
    ? `Target matching or exceeding ${exercise.lastWeekWeight}kg × ${exercise.lastWeekReps} with controlled reps.`
    : `First time on this exercise — start conservative and prioritize form.`;

  return callOllamaChat(systemPrompt, userPrompt, fallback);
}

// ── 3. Weight Progress Coach Note ───────────────────────────

export async function generateWeightCoachNote(trendData: WeightTrendInput): Promise<string> {
  const trend = trendData.trend ?? "stable";
  const delta = trendData.totalDelta ?? 0;
  const goal = trendData.goal ?? "maintain";

  const systemPrompt = `You are an empathetic, data-driven weight coach. Produce exactly ONE short, encouraging sentence (maximum 20 words) interpreting the user's weight trend. Stay strictly aligned with the trend direction (${trend}). Never contradict a losing or gaining trend. No markdown, no quotes.`;
  const userPrompt = `Goal: ${goal}, Trend: ${trend}, Weight Delta: ${delta}kg. Give one short supportive sentence.`;

  let fallback = "Holding steady over recent logs — consistency with your nutrition is key.";
  if (trend === "losing") {
    fallback = `Down ${Math.abs(delta)}kg — your pace is steady and right on track.`;
  } else if (trend === "gaining") {
    fallback = `Trending upward by ${Math.abs(delta)}kg — supporting muscle gain and strength progress.`;
  }

  return callOllamaChat(systemPrompt, userPrompt, fallback);
}

// ── 4. Routine Recommendation Coach Note ─────────────────────

interface RoutineRecommendInput {
  days: number;
  trainingExperience: string;
  goal: string;
  splitName: string;
}

export async function generateRoutineRecommendationNote(input: RoutineRecommendInput): Promise<string> {
  const expLabel = input.trainingExperience === "new"
    ? "beginner"
    : input.trainingExperience === "experienced"
    ? "experienced"
    : "intermediate";

  const systemPrompt = `You are an expert strength coach explaining why a specific routine split is recommended for a user. Write 1-2 short sentences max (maximum 35 words total). Explicitly reference their ${input.days}-day schedule, ${expLabel} experience, and ${input.goal} goal. No markdown, no quotes.`;
  const userPrompt = `Split: ${input.splitName}. User context: ${input.days} days/week, ${expLabel} experience, goal is ${input.goal}. Explain why this split is best fit.`;

  const fallback = `As a ${expLabel} lifter training ${input.days} days per week, ${input.splitName} provides the optimal balance of muscle frequency and recovery capacity for your ${input.goal} goal.`;
  return callOllamaChat(systemPrompt, userPrompt, fallback);
}
