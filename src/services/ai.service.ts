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

const SYSTEM_INSTRUCTION = `You are an expert Egyptian sports nutritionist and food analyst specializing in Egyptian cuisine, home-cooked/homemade meals, and international restaurant dishes.

Your task: Analyze the provided meal text description or screenshot and return precise nutritional macros.

CRITICAL RULES FOR NUTRITIONAL ESTIMATION:
1. PORTION & PREPARATION ESTIMATION: Be highly realistic about portion sizes and prep styles. For home-cooked meals (e.g. white rice, tagens, grilled chicken, salads), estimate based on standard Egyptian home recipes and prep weights.
2. HOMEMADE MEAL DEFAULT: If the input is a home-cooked, generic, or non-restaurant meal, or if no restaurant name is specified or identified, set "restaurantName" to "Homemade" in the JSON response.
3. MULTI-ITEM ANALYSIS: If the description contains multiple separate items (e.g. 'large chicken ranch AND a small smokey burger AND 7 diet colas'), you MUST deconstruct EACH item separately. Do not merge them into a single food object. List all their ingredients in the ingredientsBreakdown (e.g. chicken, dough/cheese for the first item, and patty, bun/cheese for the second item).
4. SIZE MULTIPLIERS: Respect size indicators strictly. A 'large' item should have roughly 1.35x standard macros/weights, while a 'small' or 'mini' item should have 0.75x or 0.5x standard macros. A 'double' patty means double the meat weight and protein.
5. BEVERAGES: Diet sodas (e.g., 'diet cola', 'coke zero', '7up diet') contain 0 calories and 0 macros. Regular sodas are highly dense in carbs (sugar).
6. INGREDIENTS BREAKDOWN: List all major ingredients with realistic weights in grams. The weights of the ingredients should reasonably correspond to the estimated macros (e.g., 100g cooked beef patty has ~25g protein and ~20g fat).
7. MACRO MATH CONSISTENCY: Your calories and macros must be mathematically aligned: Calories = (Protein * 4) + (Carbs * 4) + (Fats * 9). Adjust your estimates so this equation holds true.

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
      ? `Analyze the food in this image. If it is from the restaurant: ${input.restaurantName}, analyze it accordingly. Otherwise, if it is a home-cooked, generic, or unidentified meal, analyze it and set restaurantName to "Homemade". Return the complete nutritional breakdown.`
      : `Analyze the food/meal shown in this image. If it is from a restaurant, identify the restaurant if possible from logos or packaging. If it is a home-cooked, generic, or unidentified meal, analyze it and set restaurantName to "Homemade". Return the complete nutritional breakdown.`;

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

  const protein = Math.round(Number(parsed.protein));
  const carbs = Math.round(Number(parsed.carbs));
  const fats = Math.round(Number(parsed.fats));
  
  // Calculate consistent calories based on standard macro energy densities
  const calculatedCalories = (protein * 4) + (carbs * 4) + (fats * 9);

  return {
    mealName: String(parsed.mealName),
    restaurantName: String(parsed.restaurantName),
    calories: calculatedCalories > 0 ? calculatedCalories : Math.round(Number(parsed.calories)),
    protein,
    carbs,
    fats,
    ingredientsBreakdown: Array.isArray(parsed.ingredientsBreakdown)
      ? parsed.ingredientsBreakdown.map((item: any) => ({
          ingredient: String(item.ingredient ?? ""),
          estimatedWeightGrams: Number(item.estimatedWeightGrams ?? 0),
        }))
      : [],
  };
}
