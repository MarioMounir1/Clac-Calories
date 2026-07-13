# 🥗 Calc-Calories (The Teneen | التنين)

> **A premium, high-performance local & cloud AI-powered nutrition ecosystem. Reverse-engineer restaurant macros with Google Gemini, scan plates privately using local Llama vision models on-device, and overlay nutritional metrics on Talabat via a Chrome extension.**

[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Prisma](https://img.shields.io/badge/Prisma-ORM-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io/)
[![Ollama](https://img.shields.io/badge/Ollama-Local_AI-FF6F61?logo=ollama&logoColor=white)](https://ollama.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📖 Overview

**Calc-Calories** is an elite, hybrid-AI fitness suite designed to solve the challenge of tracking calories and macros in the Egyptian and international food markets. The ecosystem is composed of three primary pillars:

1.  **AI-First Mobile App (Flutter)**: A gorgeous dark-mode, multi-lingual app (AR/EN) supporting RTL layout, active workouts, water logging, weight logs, and a dedicated **Local AI Meal Scan** interface.
2.  **Multimodal REST Backend (Node.js & Express)**: An administrative API engine that orchestrates queries to Google Gemini (for cloud text/image queries) and local Ollama inference models (for offline private tracking). It tracks user targets, caches food logs in PostgreSQL via Prisma, and rate-limits requests.
3.  **Talabat Nutrition Overlay (Chrome Extension)**: A browser companion that reads menu items from Talabat pages and displays macro cards on screen at zero API cost once cached.

---

## ✨ System Architecture

```
                 ┌──────────────────────────────────────┐
                 │        Flutter Mobile Client         │
                 │      (The Teneen / Android & iOS)    │
                 └──────┬────────────┬────────────▲─────┘
                        │            │            │
             (HTTPS / REST)          │            │
            POST /calculate          │            │ (Scan Responses)
            POST /manual             │            │
                        │     (Local Multipart)   │
                        │     POST /scan-local    │
                        ▼            ▼            │
  ┌───────────────────────────────────────────────┴─────┐
  │              Express API Gateway (v1)               │
  │            (Authentication, DB Logger)              │
  └──────┬───────────────────┬────────────────────┬─────┘
         │                   │                    │
   (Prisma ORM)       (Cloud API Call)    (Local API Call)
         │                   │                    │
         ▼                   ▼                    ▼
┌──────────────────┐┌──────────────────┐┌──────────────────┐
│    PostgreSQL    ││  Google Gemini   ││   Local Ollama   │
│  (User Records & ││   (Flash/Pro)    ││ (llava / llama3) │
│   Cached Foods)  │└──────────────────┘└──────────────────┘
└──────────────────┘
```

---

## 🚀 Key Features

*   🦙 **Offline Local AI Processing**: Snap a plate or upload a screenshot and run inference entirely on-device (via Ollama `llava` / `llama3.2-vision`). Your meal photo never leaves your machine.
*   🥗 **Dynamic Macro Feedback**: Banners dynamically analyze the nutritional value of scanned plates (e.g., notifying you of high fat content or offering actionable suggestions to hit protein targets).
*   🤖 **Dual Cloud AI Engine**: Seamlessly switches between Gemini for hyper-accurate commercial food estimations and local Ollama models.
*   ⚡ **Egyptian Restaurant Seed**: 13 Egyptian favorites (Abo Tareq, Buffalo Burger, Kazouza, etc.) pre-mapped with deep colloquial Egyptian food knowledge (e.g. knowing 'Koshary B-Laban' is a heavy dessert, not traditional savory Koshary).
*   🌐 **Talabat Smart Badge Overlay**: Instantly updates web menu items with badges displaying protein, carb, fat, and calorie ranges.

---

## 📂 Project Structure

```
Calc-calories/
├── calc_calories_app/           # 📱 Flutter Mobile Application
│   ├── lib/
│   │   ├── core/                # Theme, Network (Dio Client), L10n Localization
│   │   └── features/
│   │       ├── auth/            # Bloc Authentication state
│   │       ├── profile/         # Onboarding & physical targets (TDEE metrics)
│   │       └── calorie_tracker/ # Main views, models (LlamaMealResponse), LocalLlamaService
├── prisma/                      # 🗄️ Database migration and seed data
│   ├── schema.prisma            # PostgreSQL Database Schema 
│   └── seed.ts                  # Bilingual Egyptian restaurants mock seeds
├── src/                         # 🛠️ Node.js REST Backend
│   ├── controllers/             # Local Llama & Meal Controllers
│   ├── routes/                  # API routers (v1 Express routing)
│   ├── services/                # Ollama, Gemini, Redis, and Prisma services
│   └── app.ts                   # Express server config
└── talabat-nutrition-extension/ # 🌐 Chrome Browser Extension
```

---

## ⚡ Setup & Quick Start

### 1. Prerequisites
*   [Node.js](https://nodejs.org/) (v18+)
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.3.0+)
*   [PostgreSQL](https://www.postgresql.org/) & [Redis](https://redis.io/)
*   [Ollama](https://ollama.com/) (For local offline model processing)

### 2. Configure Backend
1. Clone the project and install:
   ```bash
   npm install
   ```
2. Set up environment:
   ```bash
   cp .env.example .env
   ```
3. Update `.env` with your variables:
   ```env
   DATABASE_URL="postgresql://user:password@localhost:5432/nutrition_db?schema=public"
   REDIS_URL="redis://localhost:6379"
   GEMINI_API_KEY="your_google_gemini_api_key"
   AI_PROVIDER="ollama" # Set to 'ollama' or 'google'
   OLLAMA_BASE_URL="http://127.0.0.1:11434"
   OLLAMA_VISION_MODEL="llava"
   OLLAMA_MODEL="llama3"
   JWT_SECRET="generate-a-secure-random-key"
   ```
4. Push DB migrations and run pre-seed scripts:
   ```bash
   npm run db:push
   npm run db:seed
   ```
5. Run backend server:
   ```bash
   npm run dev
   ```

### 3. Run Ollama Locally
Make sure Ollama is active on your device:
```bash
# Verify connection
curl http://localhost:11434

# Pull the required text and vision models
ollama pull llama3
ollama pull llava
```

### 4. Run Flutter Mobile App
1. Navigate into the app workspace:
   ```bash
   cd calc_calories_app
   ```
2. Verify package dependencies:
   ```bash
   flutter pub get
   ```
3. Start the application:
   ```bash
   flutter run
   ```

---

## 📡 Core API Reference

### POST `/api/v1/meals/scan-local`
Accepts a raw image file, executes Ollama visual analysis on your local machine, and returns calories, macro breakdowns, and contextual fitness recommendations.

**Request Form-Data:**
*   `image`: Binary image file (screenshot or photo).

**Response (JSON):**
```json
{
  "success": true,
  "source": "local_llama_inference",
  "mealAnalysis": {
    "detectedFood": "Homemade Rice and Chicken Plate",
    "calories": 620,
    "protein": 42,
    "carbs": 80,
    "fats": 12
  },
  "llamaRecommendation": {
    "triggerWarning": true,
    "message": "Llama Notice: This meal lacks sufficient protein for your daily goal. We recommend adding 30g of protein."
  }
}
```

---

## 📄 License
Licensed under the [MIT License](LICENSE).
