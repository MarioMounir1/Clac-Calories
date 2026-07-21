// ============================================================
//  src/controllers/user.controller.ts
//  Calc-Calories — User Auth & Profile endpoints
//  POST /api/v1/auth/register
//  POST /api/v1/auth/login
//  GET  /api/v1/users/me
//  PUT  /api/v1/users/me/goals
// ============================================================

import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import jwt from "jsonwebtoken";
import prisma from "../services/prisma.service";
import { generateToken } from "../middleware/auth.middleware";

// ── User Controller ──────────────────────────────────────────

export async function upgradeUser(req: Request, res: Response): Promise<void> {
  const userId = req.user!.id;
  const secretKey = process.env.REVENUECAT_SECRET_KEY || "goog_mock_key_123456";

  try {
    // Development fallback for local simulation
    if (secretKey === "goog_mock_key_123456" || process.env.NODE_ENV !== "production") {
      console.log(`ℹ️ [Workout] Mock upgrade allowed in development/test for user: ${userId}`);
      const updated = await prisma.user.update({
        where: { id: userId },
        data: { isPremium: true },
      });
      res.json({
        success: true,
        data: { user: userPublicProfile(updated) },
      });
      return;
    }

    // Server-to-server call to RevenueCat to check subscriber data
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${userId}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${secretKey}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`❌ [RevenueCat] API Error: ${response.status} - ${errText}`);
      res.status(400).json({ success: false, error: "Failed to verify subscription with RevenueCat." });
      return;
    }

    const json = await response.json() as any;
    const subscriber = json?.subscriber;
    const entitlements = subscriber?.entitlements || {};
    
    // Check if the "premium" entitlement is active
    const premiumEntitlement = entitlements["premium"];
    const isActive = premiumEntitlement
      ? premiumEntitlement.expires_date
        ? new Date(premiumEntitlement.expires_date) > new Date()
        : true
      : false;

    if (!isActive) {
      console.warn(`⚠️ [RevenueCat] User ${userId} requested premium upgrade, but entitlement is inactive.`);
      // Sync status back to false in DB just in case
      await prisma.user.update({
        where: { id: userId },
        data: { isPremium: false },
      });
      res.status(403).json({ success: false, error: "No active premium subscription found." });
      return;
    }

    const updated = await prisma.user.update({
      where: { id: userId },
      data: { isPremium: true },
    });
    res.json({
      success: true,
      data: { user: userPublicProfile(updated) },
    });
  } catch (err) {
    console.error("❌ [Workout] upgradeUser verification error:", err);
    res.status(500).json({ success: false, error: "Upgrade verification failed." });
  }
}

export async function unsubscribeUser(req: Request, res: Response): Promise<void> {
  const userId = req.user!.id;
  try {
    const updated = await prisma.user.update({
      where: { id: userId },
      data: { isPremium: false },
    });
    res.json({
      success: true,
      data: { user: userPublicProfile(updated) },
    });
  } catch (err) {
    console.error("❌ [User] unsubscribeUser error:", err);
    res.status(500).json({ success: false, error: "Failed to remove premium membership." });
  }
}

// ── Zod Validation Schemas ─────────────────────────────────

const RegisterSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters").max(100),
  email: z.string().email("Invalid email address").toLowerCase(),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(128),
  dailyCalorieGoal: z.number().int().min(500).max(10000).optional(),
});

const LoginSchema = z.object({
  email: z.string().email("Invalid email address").toLowerCase(),
  password: z.string().min(1, "Password is required"),
});

const UpdateGoalsSchema = z.object({
  dailyCalorieGoal: z.number().int().min(500).max(10000).optional(),
  proteinGoal: z.number().int().min(0).max(1000).optional(),
  carbsGoal: z.number().int().min(0).max(2000).optional(),
  fatsGoal: z.number().int().min(0).max(500).optional(),
});

// ── Helper ─────────────────────────────────────────────────

function userPublicProfile(user: {
  id: string;
  name: string;
  email: string;
  dailyCalorieGoal: number;
  proteinGoal: number;
  carbsGoal: number;
  fatsGoal: number;
  isPremium: boolean;
  createdAt: Date;
  age?: number | null;
  weightKg?: number | null;
  heightCm?: number | null;
  targetWeightKg?: number | null;
  gender?: string | null;
  activityLevel?: string | null;
  goal?: string | null;
  language?: string | null;
}) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    isPremium: user.isPremium,
    age: user.age,
    weightKg: user.weightKg,
    heightCm: user.heightCm,
    targetWeightKg: user.targetWeightKg,
    gender: user.gender,
    activityLevel: user.activityLevel,
    goal: user.goal,
    language: user.language,
    goals: {
      dailyCalories: user.dailyCalorieGoal,
      protein: user.proteinGoal,
      carbs: user.carbsGoal,
      fats: user.fatsGoal,
    },
    createdAt: user.createdAt,
  };
}

// ── Controllers ────────────────────────────────────────────

export async function register(req: Request, res: Response): Promise<void> {
  const parsed = RegisterSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      error: "Validation failed",
      details: parsed.error.flatten().fieldErrors,
    });
    return;
  }

  const { name, email, password, dailyCalorieGoal } = parsed.data;

  try {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      res.status(409).json({
        success: false,
        error: "An account with this email already exists.",
        code: "EMAIL_TAKEN",
      });
      return;
    }

    const SALT_ROUNDS = 12;
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const user = await prisma.user.create({
      data: {
        name,
        email,
        passwordHash,
        dailyCalorieGoal: dailyCalorieGoal ?? 2000,
      },
      select: {
        id: true,
        name: true,
        email: true,
        dailyCalorieGoal: true,
        proteinGoal: true,
        carbsGoal: true,
        fatsGoal: true,
        isPremium: true,
        createdAt: true,
      },
    });

    const token = generateToken(user.id, user.email);

    console.log(`✅ [Auth] New user registered: ${email}`);
    res.status(201).json({
      success: true,
      data: {
        user: userPublicProfile(user),
        token,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [Auth] Register error:", msg);
    res.status(500).json({
      success: false,
      error: "Failed to create account. Please try again.",
      code: "REGISTER_ERROR",
    });
  }
}

export async function login(req: Request, res: Response): Promise<void> {
  const parsed = LoginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      error: "Validation failed",
      details: parsed.error.flatten().fieldErrors,
    });
    return;
  }

  const { email, password } = parsed.data;

  try {
    const user = await prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        name: true,
        email: true,
        passwordHash: true,
        isActive: true,
        dailyCalorieGoal: true,
        proteinGoal: true,
        carbsGoal: true,
        fatsGoal: true,
        isPremium: true,
        createdAt: true,
        age: true,
        weightKg: true,
        heightCm: true,
        targetWeightKg: true,
        gender: true,
        activityLevel: true,
        goal: true,
        language: true,
      },
    });

    if (!user || !user.isActive) {
      res.status(401).json({
        success: false,
        error: "Invalid email or password.",
        code: "INVALID_CREDENTIALS",
      });
      return;
    }

    if (!user.passwordHash) {
      res.status(401).json({
        success: false,
        error: "This account is configured for social sign-in. Please log in with Google or Apple.",
        code: "SOCIAL_ONLY_ACCOUNT",
      });
      return;
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      res.status(401).json({
        success: false,
        error: "Invalid email or password.",
        code: "INVALID_CREDENTIALS",
      });
      return;
    }

    const token = generateToken(user.id, user.email);

    console.log(`✅ [Auth] User logged in: ${email}`);
    res.json({
      success: true,
      data: {
        user: userPublicProfile(user),
        token,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [Auth] Login error:", msg);
    res.status(500).json({
      success: false,
      error: "Login service temporarily unavailable.",
      code: "LOGIN_ERROR",
    });
  }
}

export async function getMe(req: Request, res: Response): Promise<void> {
  const userId = req.user!.id;

  try {
    // Get user + today's meal logs for daily summary
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [user, todayLogs] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          name: true,
          email: true,
          dailyCalorieGoal: true,
          proteinGoal: true,
          carbsGoal: true,
          fatsGoal: true,
          isPremium: true,
          createdAt: true,
          age: true,
          weightKg: true,
          heightCm: true,
          targetWeightKg: true,
          gender: true,
          activityLevel: true,
          goal: true,
          language: true,
        },
      }),
      prisma.mealLog.findMany({
        where: {
          userId,
          createdAt: { gte: today, lt: tomorrow },
        },
        select: { calories: true, protein: true, carbs: true, fats: true },
      }),
    ]);

    if (!user) {
      res.status(404).json({ success: false, error: "User not found." });
      return;
    }

    const todayTotals = todayLogs.reduce(
      (acc, log) => ({
        calories: acc.calories + log.calories,
        protein: acc.protein + log.protein,
        carbs: acc.carbs + log.carbs,
        fats: acc.fats + log.fats,
      }),
      { calories: 0, protein: 0, carbs: 0, fats: 0 }
    );

    res.json({
      success: true,
      data: {
        user: userPublicProfile(user),
        todaySummary: {
          consumed: todayTotals,
          remaining: {
            calories: Math.max(0, user.dailyCalorieGoal - todayTotals.calories),
            protein: Math.max(0, user.proteinGoal - todayTotals.protein),
            carbs: Math.max(0, user.carbsGoal - todayTotals.carbs),
            fats: Math.max(0, user.fatsGoal - todayTotals.fats),
          },
          mealsLogged: todayLogs.length,
        },
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [User] getMe error:", msg);
    res.status(500).json({ success: false, error: "Failed to load profile." });
  }
}

export async function updateGoals(req: Request, res: Response): Promise<void> {
  const userId = req.user!.id;

  const parsed = UpdateGoalsSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      error: "Validation failed",
      details: parsed.error.flatten().fieldErrors,
    });
    return;
  }

  if (Object.keys(parsed.data).length === 0) {
    res.status(400).json({
      success: false,
      error: "No goals provided to update.",
    });
    return;
  }

  try {
    const updated = await prisma.user.update({
      where: { id: userId },
      data: parsed.data,
      select: {
        id: true,
        name: true,
        email: true,
        dailyCalorieGoal: true,
        proteinGoal: true,
        carbsGoal: true,
        fatsGoal: true,
        isPremium: true,
        createdAt: true,
      },
    });

    res.json({
      success: true,
      data: { user: userPublicProfile(updated) },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [User] updateGoals error:", msg);
    res.status(500).json({ success: false, error: "Failed to update goals." });
  }
}

// ── Social Auth Controllers ────────────────────────────────

const GoogleLoginSchema = z.object({
  idToken: z.string().optional(),
  email: z.string().email("Invalid email address").toLowerCase(),
  name: z.string().min(2, "Name must be at least 2 characters").max(100),
  googleId: z.string().min(1, "Google ID is required"),
});

const AppleLoginSchema = z.object({
  identityToken: z.string().optional(),
  email: z.string().email("Invalid email address").toLowerCase(),
  name: z.string().min(2, "Name must be at least 2 characters").max(100),
  appleId: z.string().min(1, "Apple ID is required"),
});

export async function googleLogin(req: Request, res: Response): Promise<void> {
  const parsed = GoogleLoginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      error: "Validation failed",
      details: parsed.error.flatten().fieldErrors,
    });
    return;
  }

  const { idToken, email, name, googleId } = parsed.data;
  let verifiedEmail = email;
  let verifiedGoogleId = googleId;

  if (idToken) {
    try {
      const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
      if (response.ok) {
        const ticket = (await response.json()) as any;
        if (ticket.email) {
          verifiedEmail = ticket.email.toLowerCase();
        }
        if (ticket.sub) {
          verifiedGoogleId = ticket.sub;
        }
      } else {
        console.warn("⚠️ [Auth] Google Token verification returned error code:", response.status);
        if (process.env.NODE_ENV === "production") {
          res.status(401).json({
            success: false,
            error: "Invalid Google ID token.",
            code: "INVALID_GOOGLE_TOKEN",
          });
          return;
        }
      }
    } catch (err) {
      console.error("❌ [Auth] Google token verification failed:", err);
      if (process.env.NODE_ENV === "production") {
        res.status(401).json({
          success: false,
          error: "Failed to verify Google token.",
          code: "GOOGLE_VERIFY_ERROR",
        });
        return;
      }
    }
  }

  try {
    let user = await prisma.user.findUnique({
      where: { googleId: verifiedGoogleId },
    });

    if (!user) {
      user = await prisma.user.findUnique({
        where: { email: verifiedEmail },
      });

      if (user) {
        user = await prisma.user.update({
          where: { id: user.id },
          data: { googleId: verifiedGoogleId },
        });
        console.log(`🔗 [Auth] Linked Google account to existing user: ${verifiedEmail}`);
      } else {
        user = await prisma.user.create({
          data: {
            name,
            email: verifiedEmail,
            googleId: verifiedGoogleId,
            dailyCalorieGoal: 2000,
          },
        });
        console.log(`✅ [Auth] Created new user via Google: ${verifiedEmail}`);
      }
    }

    if (!user.isActive) {
      res.status(401).json({
        success: false,
        error: "This account has been deactivated.",
        code: "USER_DEACTIVATED",
      });
      return;
    }

    const token = generateToken(user.id, user.email);

    res.json({
      success: true,
      data: {
        user: userPublicProfile(user),
        token,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [Auth] Google login error:", msg);
    res.status(500).json({
      success: false,
      error: "Google login service temporarily unavailable.",
      code: "GOOGLE_LOGIN_ERROR",
    });
  }
}

export async function appleLogin(req: Request, res: Response): Promise<void> {
  const parsed = AppleLoginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({
      success: false,
      error: "Validation failed",
      details: parsed.error.flatten().fieldErrors,
    });
    return;
  }

  const { identityToken, email, name, appleId } = parsed.data;
  let verifiedEmail = email;
  let verifiedAppleId = appleId;

  if (identityToken) {
    try {
      const decoded = jwt.decode(identityToken) as any;
      if (decoded) {
        if (decoded.email) {
          verifiedEmail = decoded.email.toLowerCase();
        }
        if (decoded.sub) {
          verifiedAppleId = decoded.sub;
        }
      }
    } catch (err) {
      console.error("❌ [Auth] Apple token decoding failed:", err);
    }
  }

  try {
    let user = await prisma.user.findUnique({
      where: { appleId: verifiedAppleId },
    });

    if (!user) {
      user = await prisma.user.findUnique({
        where: { email: verifiedEmail },
      });

      if (user) {
        user = await prisma.user.update({
          where: { id: user.id },
          data: { appleId: verifiedAppleId },
        });
        console.log(`🔗 [Auth] Linked Apple account to existing user: ${verifiedEmail}`);
      } else {
        user = await prisma.user.create({
          data: {
            name,
            email: verifiedEmail,
            appleId: verifiedAppleId,
            dailyCalorieGoal: 2000,
          },
        });
        console.log(`✅ [Auth] Created new user via Apple: ${verifiedEmail}`);
      }
    }

    if (!user.isActive) {
      res.status(401).json({
        success: false,
        error: "This account has been deactivated.",
        code: "USER_DEACTIVATED",
      });
      return;
    }

    const token = generateToken(user.id, user.email);

    res.json({
      success: true,
      data: {
        user: userPublicProfile(user),
        token,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("❌ [Auth] Apple login error:", msg);
    res.status(500).json({
      success: false,
      error: "Apple login service temporarily unavailable.",
      code: "APPLE_LOGIN_ERROR",
    });
  }
}

// ── RevenueCat Webhook ─────────────────────────────────────
export async function revenueCatWebhook(req: Request, res: Response): Promise<void> {
  const webhookSecret = process.env.REVENUECAT_WEBHOOK_SECRET;
  const authHeader = req.headers.authorization;

  // Authorization token verification
  if (webhookSecret && authHeader !== `Bearer ${webhookSecret}`) {
    console.warn("⚠️ [RevenueCat Webhook] Rejected unauthorized request headers.");
    res.status(401).json({ success: false, error: "Unauthorized webhook caller." });
    return;
  }

  const event = req.body?.event;
  if (!event) {
    res.status(400).json({ success: false, error: "Missing event payload." });
    return;
  }

  const type = event.type;
  const appUserId = event.app_user_id;
  const entitlementId = event.entitlement_id;
  const entitlementIds = event.entitlement_ids || [];

  // Verify this event pertains to our "premium" entitlement
  const hasPremiumEntitlement = entitlementId === "premium" || entitlementIds.includes("premium");
  if (!hasPremiumEntitlement) {
    res.json({ success: true, message: "Ignored: Event not related to premium entitlement." });
    return;
  }

  try {
    switch (type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
        await prisma.user.update({
          where: { id: appUserId },
          data: { isPremium: true },
        });
        console.log(`✅ [RevenueCat Webhook] Subscribed user ${appUserId} to premium via ${type}.`);
        break;

      case "EXPIRATION":
      case "REVOCATION":
        await prisma.user.update({
          where: { id: appUserId },
          data: { isPremium: false },
        });
        console.log(`⚠️ [RevenueCat Webhook] Suspended premium user ${appUserId} due to ${type}.`);
        break;

      default:
        console.log(`ℹ️ [RevenueCat Webhook] Event ${type} processed (no db action needed).`);
        break;
    }

    res.json({ success: true });
  } catch (err) {
    console.error("❌ [RevenueCat Webhook] Database update failed:", err);
    res.status(500).json({ success: false, error: "Database transaction failed." });
  }
}

