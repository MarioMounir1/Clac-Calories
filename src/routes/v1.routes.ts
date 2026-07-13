// ============================================================
//  src/routes/v1.routes.ts
//  Calc-Calories — API v1 Router
//  All mobile app endpoints live here under /api/v1
// ============================================================

import { Router } from "express";
import { register, login, getMe, updateGoals } from "../controllers/user.controller";
import { analyzeMealHandler, manualLogMealHandler } from "../controllers/meal.controller";
import { scanLocalHandler } from "../controllers/local-llama.controller";
import { getMealHistory, deleteMealLog } from "../controllers/history.controller";
import { getSuggestions } from "../controllers/suggestion.controller";
import { updateProfile, getTdee } from "../controllers/profile.controller";
import { searchFoods, getFoodById, getFoodCategories } from "../controllers/food.controller";
import { logFood, getTodayFoodLogs, deleteFoodLog } from "../controllers/food-log.controller";
import { logWater, getTodayWater, deleteWaterLog } from "../controllers/water.controller";
import { logWeight, getWeightHistory, deleteWeightLog } from "../controllers/weight.controller";
import { getTodayMealPlan, getWeekMealPlan, generateMealPlan, markAsEaten } from "../controllers/meal-plan.controller";
import { requireAuth } from "../middleware/auth.middleware";
import { analyzeMealLimiter, authLimiter } from "../middleware/rateLimit.middleware";

const router = Router();

// ── Auth Routes ────────────────────────────────────────────

/**
 * @route   POST /api/v1/auth/register
 * @desc    Create a new Calc-Calories user account
 * @access  Public
 * @body    { name, email, password, dailyCalorieGoal? }
 */
router.post("/auth/register", authLimiter, register);

/**
 * @route   POST /api/v1/auth/login
 * @desc    Authenticate and receive a JWT token
 * @access  Public
 * @body    { email, password }
 */
router.post("/auth/login", authLimiter, login);

// ── User Routes ────────────────────────────────────────────

/**
 * @route   GET /api/v1/users/me
 * @desc    Get current user profile + today's macro summary
 * @access  Private (JWT required)
 */
router.get("/users/me", requireAuth, getMe);

/**
 * @route   PUT /api/v1/users/me/goals
 * @desc    Update daily calorie and macro goals
 * @access  Private (JWT required)
 * @body    { dailyCalorieGoal?, proteinGoal?, carbsGoal?, fatsGoal? }
 */
router.put("/users/me/goals", requireAuth, updateGoals);

/**
 * @route   PUT /api/v1/users/profile
 * @desc    Update user physical profile (age, weight, height, gender, goal, language)
 *          Automatically recalculates daily calorie + macro goals via TDEE
 * @access  Private (JWT required)
 * @body    { name?, age?, weightKg?, heightCm?, gender?, activityLevel?, goal?, language? }
 */
router.put("/users/profile", requireAuth, updateProfile);

/**
 * @route   GET /api/v1/users/tdee
 * @desc    Calculate and return TDEE breakdown using Mifflin-St Jeor formula
 * @access  Private (JWT required)
 */
router.get("/users/tdee", requireAuth, getTdee);

// ── Food Database Routes ───────────────────────────────────

/**
 * @route   GET /api/v1/foods/search
 * @desc    Search Egyptian food database by name (Arabic or English)
 * @access  Private (JWT required)
 * @query   q (required), lang? (en|ar), category?, limit?, page?
 */
router.get("/foods/search", requireAuth, searchFoods);

/**
 * @route   GET /api/v1/foods/categories
 * @desc    List all food categories with bilingual labels and item counts
 * @access  Private (JWT required)
 */
router.get("/foods/categories", requireAuth, getFoodCategories);

/**
 * @route   GET /api/v1/foods/:id
 * @desc    Get a single food item by ID with full nutritional details
 * @access  Private (JWT required)
 */
router.get("/foods/:id", requireAuth, getFoodById);

// ── Food Log Routes ─────────────────────────────────────────

/**
 * @route   POST /api/v1/food-logs
 * @desc    Log a food item from the database for today
 * @access  Private (JWT required)
 * @body    { foodItemId, servings?, mealType?, loggedAt? }
 */
router.post("/food-logs", requireAuth, logFood);

/**
 * @route   GET /api/v1/food-logs/today
 * @desc    Get today's combined food log summary (DB entries + AI scans) with totals vs goals
 * @access  Private (JWT required)
 * @query   date? (YYYY-MM-DD, defaults to today)
 */
router.get("/food-logs/today", requireAuth, getTodayFoodLogs);

/**
 * @route   DELETE /api/v1/food-logs/:id
 * @desc    Delete a specific food log entry
 * @access  Private (JWT required, ownership enforced)
 */
router.delete("/food-logs/:id", requireAuth, deleteFoodLog);

// ── Water Tracking Routes ──────────────────────────────────

/**
 * @route   POST /api/v1/water
 * @desc    Log water intake (in ml)
 * @access  Private (JWT required)
 * @body    { amountMl, loggedAt? }
 */
router.post("/water", requireAuth, logWater);

/**
 * @route   GET /api/v1/water/today
 * @desc    Get today's water intake total, progress vs goal, and hourly breakdown
 * @access  Private (JWT required)
 * @query   date? (YYYY-MM-DD, defaults to today)
 */
router.get("/water/today", requireAuth, getTodayWater);

/**
 * @route   DELETE /api/v1/water/:id
 * @desc    Delete a specific water log entry
 * @access  Private (JWT required, ownership enforced)
 */
router.delete("/water/:id", requireAuth, deleteWaterLog);

// ── Weight Tracking Routes ──────────────────────────────────

/**
 * @route   POST /api/v1/weight
 * @desc    Log today's weight (also updates user profile for TDEE accuracy)
 * @access  Private (JWT required)
 * @body    { weightKg, loggedAt? }
 */
router.post("/weight", requireAuth, logWeight);

/**
 * @route   GET /api/v1/weight/history
 * @desc    Get weight history with stats (delta, trend, min/max/avg)
 * @access  Private (JWT required)
 * @query   days? (7–365, default 30)
 */
router.get("/weight/history", requireAuth, getWeightHistory);

/**
 * @route   DELETE /api/v1/weight/:id
 * @desc    Delete a specific weight log entry
 * @access  Private (JWT required, ownership enforced)
 */
router.delete("/weight/:id", requireAuth, deleteWeightLog);

// ── Meal Plan Routes ─────────────────────────────────────────

/**
 * @route   GET /api/v1/meal-plans/today
 * @desc    Get today's meal plan entries with totals
 * @access  Private (JWT required)
 */
router.get("/meal-plans/today", requireAuth, getTodayMealPlan);

/**
 * @route   GET /api/v1/meal-plans/week
 * @desc    Get full week meal plan grouped by day
 * @access  Private (JWT required)
 */
router.get("/meal-plans/week", requireAuth, getWeekMealPlan);

/**
 * @route   POST /api/v1/meal-plans/generate
 * @desc    Auto-generate a weekly meal plan based on user calorie goal
 *          (replaces existing plan for the current week)
 * @access  Private (JWT required)
 */
router.post("/meal-plans/generate", requireAuth, generateMealPlan);

/**
 * @route   PUT /api/v1/meal-plans/:id/eaten
 * @desc    Toggle a meal plan entry as eaten / not eaten
 * @access  Private (JWT required, ownership enforced)
 * @body    { isEaten?: boolean } (defaults to true)
 */
router.put("/meal-plans/:id/eaten", requireAuth, markAsEaten);

// ── Meal Analysis Routes ───────────────────────────────────

/**
 * @route   POST /api/v1/meals/analyze
 * @desc    Analyze a meal via text description OR image screenshot
 * @access  Private (JWT required)
 * @body    multipart/form-data: { restaurantName?, mealDescription?, image? }
 *          OR application/json: { restaurantName, mealDescription }
 * @rateLimit 30 requests per minute per user
 */
router.post("/meals/analyze", requireAuth, analyzeMealLimiter, analyzeMealHandler);

/**
 * @route   POST /api/v1/meals/scan-local
 * @desc    Analyze a meal image using the local Llama vision model (Ollama)
 *          Returns structured macros + contextual AI recommendation
 * @access  Private (JWT required)
 * @body    multipart/form-data: { image (file) }
 * @rateLimit 30 requests per minute per user
 */
router.post("/meals/scan-local", requireAuth, analyzeMealLimiter, scanLocalHandler);

/**
 * @route   POST /api/v1/meals/manual
 * @desc    Manually log a meal with known macros (no AI)
 * @access  Private
 * @body    { mealName?, calories, protein, carbs, fats, mealType? }
 */
router.post("/meals/manual", requireAuth, manualLogMealHandler);

/**
 * @route   GET /api/v1/meals/history
 * @desc    Get paginated meal log history
 * @access  Private (JWT required)
 * @query   page?, limit?, date? (YYYY-MM-DD)
 */
router.get("/meals/history", requireAuth, getMealHistory);

/**
 * @route   GET /api/v1/meals/suggestions
 * @desc    Get macro suggestions and recommended protein products
 * @access  Private (JWT required)
 */
router.get("/meals/suggestions", requireAuth, getSuggestions);

/**
 * @route   DELETE /api/v1/meals/:id
 * @desc    Delete a specific meal log entry
 * @access  Private (JWT required, ownership enforced)
 */
router.delete("/meals/:id", requireAuth, deleteMealLog);

export default router;
