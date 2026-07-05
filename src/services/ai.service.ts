// ============================================================
//  src/services/ai.service.ts
//  Calc-Calories — Multimodal AI Service (text + image → macros)
//  Automatically switches between Google Gemini and Local Ollama (Llama 3)
// ============================================================

import {
  GoogleGenerativeAI,
  SchemaType,
  Part,
  InlineDataPart,
} from "@google/generative-ai";
import { OLLAMA_CONFIG } from "../config";

const apiKey = process.env.GEMINI_API_KEY ?? "";
const genAI = new GoogleGenerativeAI(apiKey);

// ── Response Types ─────────────────────────────────────────

export interface IngredientBreakdown {
  ingredient: string;
  estimatedWeightGrams: number;
}

export interface MealAnalysisResult {
  mealName: string;
  restaurantName: string;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  ingredientsBreakdown: IngredientBreakdown[];
}

export interface AnalyzeTextInput {
  type: "text";
  restaurantName: string;
  mealDescription: string;
}

export interface AnalyzeImageInput {
  type: "image";
  imageBuffer: Buffer;
  mimeType: "image/jpeg" | "image/png" | "image/webp";
  restaurantName?: string;
}

export type AnalyzeInput = AnalyzeTextInput | AnalyzeImageInput;

// ── Gemini JSON Response Schema ────────────────────────────

const RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    mealName: { type: SchemaType.STRING },
    restaurantName: { type: SchemaType.STRING },
    calories: { type: SchemaType.NUMBER },
    protein: { type: SchemaType.NUMBER },
    carbs: { type: SchemaType.NUMBER },
    fats: { type: SchemaType.NUMBER },
    ingredientsBreakdown: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          ingredient: { type: SchemaType.STRING },
          estimatedWeightGrams: { type: SchemaType.NUMBER },
        },
        required: ["ingredient", "estimatedWeightGrams"],
      },
    },
  },
  required: [
    "mealName",
    "restaurantName",
    "calories",
    "protein",
    "carbs",
    "fats",
    "ingredientsBreakdown",
  ],
};

// ── System Instruction ─────────────────────────────────────

const SYSTEM_INSTRUCTION = `You are an expert Egyptian sports nutritionist and food analyst specializing in Egyptian and international restaurant cuisine.

Your task: Analyze the provided meal (either a text description or a screenshot/photo of food) and return precise nutritional macros.

CRITICAL RULES:
1. Be realistic about Egyptian restaurant portion sizes. Egyptian restaurants serve standard portions.
2. For burgers/sandwiches: Account for the full meal (bun + patty + toppings + included sides).
3. For combos/meals: Deconstruct ALL components and SUM their macros.
4. Return calories as kcal (a single realistic integer).
5. All macro values (protein, carbs, fats) must be in grams as realistic integers.
6. The ingredientsBreakdown must list every major component with a realistic estimated weight.
7. Egyptian-specific dishes: Koshary (500-700 kcal), Falafel sandwich (350-450 kcal), Shawarma (450-600 kcal), Ful medames (300-400 kcal).

Always return a valid JSON object matching this structure:
{
  "mealName": "string",
  "restaurantName": "string",
  "calories": number,
  "protein": number,
  "carbs": number,
  "fats": number,
  "ingredientsBreakdown": [{"ingredient": "string", "estimatedWeightGrams": number}]
}`;

// ── Core AI Analysis Function ──────────────────────────────

export async function analyzeMeal(input: AnalyzeInput): Promise<MealAnalysisResult> {
  const provider = process.env.AI_PROVIDER ?? "google";

  if (provider === "ollama") {
    if (input.type === "image") {
      throw new Error("Local Ollama (Llama 3) does not support multimodal image analysis. Please use text description or set AI_PROVIDER=google.");
    }
    return analyzeWithOllama(input);
  }

  return analyzeWithGemini(input);
}

// ── Local Ollama (Llama 3) Implementation ──────────────────

async function analyzeWithOllama(input: AnalyzeTextInput): Promise<MealAnalysisResult> {
  console.log(`🔮 Calling local Ollama (${OLLAMA_CONFIG.model}): ${input.restaurantName} — ${input.mealDescription}`);
  
  const userPrompt = `Restaurant: ${input.restaurantName}
Meal Description: ${input.mealDescription}

Analyze the nutritional content of this specific meal from this Egyptian restaurant and return the macros.`;

  const response = await fetch(`${OLLAMA_CONFIG.baseUrl}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: OLLAMA_CONFIG.model,
      messages: [
        { role: "system", content: SYSTEM_INSTRUCTION },
        { role: "user", content: userPrompt },
      ],
      stream: false,
      options: {
        temperature: OLLAMA_CONFIG.temperature,
      },
      format: "json",
    }),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "");
    throw new Error(`Ollama API error: ${response.status} ${response.statusText} - ${errorText}`);
  }

  const responseData = await response.json() as any;
  const responseText = responseData.message?.content?.trim();

  if (!responseText) {
    throw new Error("Empty response from Ollama API");
  }

  let parsed: any;
  try {
    parsed = JSON.parse(responseText);
  } catch (err) {
    throw new Error(`Ollama returned invalid JSON response: ${responseText.slice(0, 200)}`);
  }

  return parseAndValidateResponse(parsed);
}

// ── Google Gemini Implementation ───────────────────────────

async function analyzeWithGemini(input: AnalyzeInput): Promise<MealAnalysisResult> {
  const modelName = process.env.GEMINI_MODEL ?? "gemini-1.5-pro";
  console.log(`🔮 Calling Gemini API (${modelName}): ${input.type === "text" ? input.mealDescription : "Image buffer"}`);

  const model = genAI.getGenerativeModel({
    model: modelName,
    systemInstruction: SYSTEM_INSTRUCTION,
  });

  const generationConfig = {
    responseMimeType: "application/json",
    responseSchema: RESPONSE_SCHEMA as any,
    temperature: 0.1,
    topP: 0.8,
    topK: 40,
    maxOutputTokens: 4096,
  };

  let parts: Part[];

  if (input.type === "text") {
    const prompt = `Restaurant: ${input.restaurantName}
Meal Description: ${input.mealDescription}

Analyze the nutritional content of this specific meal from this Egyptian restaurant and return the macros.`;

    parts = [{ text: prompt }];
  } else {
    const base64Image = input.imageBuffer.toString("base64");
    const imagePart: InlineDataPart = {
      inlineData: {
        data: base64Image,
        mimeType: input.mimeType,
      },
    };

    const textPrompt = input.restaurantName
      ? `This is a food image from the restaurant: ${input.restaurantName}. Analyze the meal in this image and return its complete nutritional breakdown.`
      : `Analyze the food/meal shown in this image. Identify the restaurant if possible from logos or packaging. Return the complete nutritional breakdown.`;

    parts = [imagePart, { text: textPrompt }];
  }

  let responseText: string;
  try {
    const result = await model.generateContent({
      contents: [{ role: "user", parts }],
      generationConfig,
    });
    responseText = result.response.text();
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`Gemini API call failed: ${msg}`);
  }

  if (!responseText || responseText.trim() === "") {
    throw new Error("Gemini returned an empty response.");
  }

  let parsed: any;
  try {
    parsed = JSON.parse(responseText);
  } catch {
    throw new Error(`Gemini returned invalid JSON: ${responseText.slice(0, 200)}`);
  }

  return parseAndValidateResponse(parsed);
}

// ── Helper Parser & Validator ──────────────────────────────

function parseAndValidateResponse(parsed: any): MealAnalysisResult {
  const required = ["mealName", "restaurantName", "calories", "protein", "carbs", "fats"];
  for (const field of required) {
    if (parsed[field] === undefined || parsed[field] === null) {
      throw new Error(`AI response missing required field: "${field}"`);
    }
  }

  return {
    mealName: String(parsed.mealName),
    restaurantName: String(parsed.restaurantName),
    calories: Number(parsed.calories),
    protein: Number(parsed.protein),
    carbs: Number(parsed.carbs),
    fats: Number(parsed.fats),
    ingredientsBreakdown: Array.isArray(parsed.ingredientsBreakdown)
      ? parsed.ingredientsBreakdown.map((item: any) => ({
          ingredient: String(item.ingredient ?? ""),
          estimatedWeightGrams: Number(item.estimatedWeightGrams ?? 0),
        }))
      : [],
  };
}
