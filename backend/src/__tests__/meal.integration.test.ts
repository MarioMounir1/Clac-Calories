// Set env vars BEFORE any module imports that read them at load time
process.env.JWT_SECRET = 'test-jwt-secret-for-ci-pipeline-only';
process.env.GEMINI_API_KEY = 'test-key-not-real';
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test_db';
import request from 'supertest';
import app from '../app';

// Mock the AI service to avoid real Gemini calls in tests
jest.mock('../services/ai.service', () => ({
  analyzeMeal: jest.fn().mockResolvedValue({
    mealName: 'Single Bacon Mushroom Jack',
    restaurantName: 'Buffalo Burger',
    calories: 650,
    protein: 42,
    carbs: 48,
    fats: 28,
    ingredientsBreakdown: [
      { ingredient: 'Beef Patty', estimatedWeightGrams: 113 },
      { ingredient: 'Bun', estimatedWeightGrams: 60 },
    ],
  }),
}));

// Mock Prisma to avoid real DB calls
jest.mock('../services/prisma.service', () => ({
  __esModule: true,
  default: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    mealLog: {
      create: jest.fn().mockResolvedValue({ id: 'test-log-id-123' }),
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      findUnique: jest.fn(),
      delete: jest.fn(),
    },
    company: {
      upsert: jest.fn().mockResolvedValue({}),
    },
    $connect: jest.fn(),
    $disconnect: jest.fn(),
  },
}));


// Mock Redis to avoid connection
jest.mock('../services/redis.service', () => ({
  default: {
    get: jest.fn().mockResolvedValue(null),
    setex: jest.fn(),
    pipeline: jest.fn().mockReturnValue({
      incr: jest.fn().mockReturnThis(),
      ttl: jest.fn().mockReturnThis(),
      exec: jest.fn().mockResolvedValue([[null, 1], [null, 60]]),
    }),
    expire: jest.fn(),
    status: 'ready',
  },
  isRedisReady: jest.fn().mockReturnValue(false), // Disable caching in tests
}));

const prisma = require('../services/prisma.service').default;

// ── Test helpers ───────────────────────────────────────────

const TEST_USER = {
  id: 'test-user-id-123',
  email: 'test@calc-calories.io',
  name: 'Test User',
  isActive: true,
};

let authToken: string;

// Generate a real JWT for testing
function generateTestToken(): string {
  const jwt = require('jsonwebtoken');
  return jwt.sign(
    { userId: TEST_USER.id, email: TEST_USER.email },
    process.env.JWT_SECRET ?? 'test-jwt-secret-for-ci-pipeline-only',
    { expiresIn: '1h' }
  );
}

beforeAll(() => {
  // Mock user lookup for auth middleware
  prisma.user.findUnique.mockResolvedValue(TEST_USER);

  // Generate JWT with the SAME secret set at module top
  authToken = generateTestToken();
});

afterAll(async () => {
  // Allow open handles to close
  await new Promise((resolve) => setTimeout(resolve, 200));
});

// ── Tests ──────────────────────────────────────────────────

describe('Health Check', () => {
  it('GET /health returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.version).toBe('2.0.0');
  });
});

describe('POST /api/v1/meals/analyze — Text Mode', () => {
  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/api/v1/meals/analyze')
      .send({ restaurantName: 'Buffalo Burger', mealDescription: 'Single Burger' });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.code).toBe('MISSING_TOKEN');
  });

  it('succeeds (returns 201) when restaurantName is missing by defaulting it', async () => {
    const res = await request(app)
      .post('/api/v1/meals/analyze')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ mealDescription: 'Single Burger' });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });

  it('returns 400 when mealDescription is missing', async () => {
    const res = await request(app)
      .post('/api/v1/meals/analyze')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ restaurantName: 'Buffalo Burger' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('returns 201 with structured macro data for valid text input', async () => {
    const res = await request(app)
      .post('/api/v1/meals/analyze')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        restaurantName: 'Buffalo Burger',
        mealDescription: 'Single Bacon Mushroom Jack',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.source).toBe('ai');
    expect(res.body.data).toMatchObject({
      mealName: expect.any(String),
      restaurantName: expect.any(String),
      calories: expect.any(Number),
      protein: expect.any(Number),
      carbs: expect.any(Number),
      fats: expect.any(Number),
      ingredientsBreakdown: expect.any(Array),
    });
    expect(res.body.data.calories).toBeGreaterThan(0);
    expect(res.body.data.ingredientsBreakdown.length).toBeGreaterThan(0);
  });
});

describe('GET /api/v1/meals/history', () => {
  it('returns 401 without auth token', async () => {
    const res = await request(app).get('/api/v1/meals/history');
    expect(res.status).toBe(401);
  });

  it('returns paginated history for authenticated user', async () => {
    const res = await request(app)
      .get('/api/v1/meals/history')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveProperty('logs');
    expect(res.body.data).toHaveProperty('pagination');
    expect(res.body.data).toHaveProperty('totals');
    expect(Array.isArray(res.body.data.logs)).toBe(true);
  });

  it('accepts date filter query param', async () => {
    const res = await request(app)
      .get('/api/v1/meals/history?date=2025-07-05')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
  });

  it('rejects invalid date format', async () => {
    const res = await request(app)
      .get('/api/v1/meals/history?date=not-a-date')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(400);
  });
});

describe('Auth Routes', () => {
  it('POST /api/v1/auth/register returns 400 for short password', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      name: 'Test User',
      email: 'newuser@test.com',
      password: '123',
    });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.details?.password).toBeDefined();
  });

  it('POST /api/v1/auth/login returns 400 for missing fields', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({});
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });
});
