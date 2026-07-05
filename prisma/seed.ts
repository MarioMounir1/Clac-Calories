// ============================================================
//  prisma/seed.ts
//  Database seeding: Egyptian restaurants + food items (bilingual)
//  Run with: npm run db:seed
// ============================================================

import "dotenv/config";
import process from "process";
import prisma from "../src/services/prisma.service";

// ---------------------------------------------------------------------------
// Egyptian Food Items — ~100 common items bilingual (Arabic + English)
// Calories/protein/carbs/fats are per default servingSize
// ---------------------------------------------------------------------------
const foodItems = [
  // ── Breakfast ────────────────────────────────────────────────────────────
  { nameEn: "Ful Medames", nameAr: "فول مدمس", calories: 190, protein: 10, carbs: 28, fats: 5, fiber: 8, servingSize: 200, servingUnit: "g", category: "breakfast" },
  { nameEn: "Falafel (Ta'meya)", nameAr: "طعمية", calories: 180, protein: 7, carbs: 20, fats: 9, fiber: 4, servingSize: 100, servingUnit: "g", category: "breakfast" },
  { nameEn: "Baladi Bread", nameAr: "عيش بلدي", calories: 130, protein: 4, carbs: 26, fats: 1, fiber: 2, servingSize: 60, servingUnit: "g", category: "breakfast" },
  { nameEn: "Fino Bread", nameAr: "عيش فينو", calories: 150, protein: 5, carbs: 28, fats: 2, fiber: 1, servingSize: 60, servingUnit: "g", category: "breakfast" },
  { nameEn: "Egg (Boiled)", nameAr: "بيضة مسلوقة", calories: 78, protein: 6, carbs: 1, fats: 5, fiber: 0, servingSize: 50, servingUnit: "g", category: "breakfast" },
  { nameEn: "Egg (Fried)", nameAr: "بيضة مقلية", calories: 100, protein: 6, carbs: 1, fats: 8, fiber: 0, servingSize: 50, servingUnit: "g", category: "breakfast" },
  { nameEn: "White Cheese (Gebna Beyda)", nameAr: "جبنة بيضاء", calories: 90, protein: 6, carbs: 1, fats: 7, fiber: 0, servingSize: 50, servingUnit: "g", category: "breakfast" },
  { nameEn: "Rumi Cheese", nameAr: "جبنة رومي", calories: 110, protein: 8, carbs: 1, fats: 9, fiber: 0, servingSize: 50, servingUnit: "g", category: "breakfast" },
  { nameEn: "Processed Cheese Triangle", nameAr: "جبنة مثلثات", calories: 70, protein: 4, carbs: 2, fats: 5, fiber: 0, servingSize: 30, servingUnit: "g", category: "breakfast" },
  { nameEn: "Tahini", nameAr: "طحينة", calories: 180, protein: 5, carbs: 8, fats: 16, fiber: 1, servingSize: 30, servingUnit: "g", category: "breakfast" },
  { nameEn: "Halawa", nameAr: "حلاوة طحينية", calories: 175, protein: 5, carbs: 18, fats: 10, fiber: 1, servingSize: 40, servingUnit: "g", category: "breakfast" },
  { nameEn: "Honey", nameAr: "عسل", calories: 64, protein: 0, carbs: 17, fats: 0, fiber: 0, servingSize: 20, servingUnit: "g", category: "breakfast" },

  // ── Lunch / Main Meals ───────────────────────────────────────────────────
  { nameEn: "Koshary (Medium Portion)", nameAr: "كشري (حصة متوسطة)", calories: 450, protein: 14, carbs: 82, fats: 8, fiber: 6, servingSize: 350, servingUnit: "g", category: "lunch" },
  { nameEn: "Koshary (Large Portion)", nameAr: "كشري (حصة كبيرة)", calories: 640, protein: 20, carbs: 117, fats: 11, fiber: 9, servingSize: 500, servingUnit: "g", category: "lunch" },
  { nameEn: "Molokhia with Chicken", nameAr: "ملوخية بالدجاج", calories: 280, protein: 25, carbs: 12, fats: 14, fiber: 3, servingSize: 300, servingUnit: "g", category: "lunch" },
  { nameEn: "Molokhia with Rabbit", nameAr: "ملوخية بالأرانب", calories: 310, protein: 28, carbs: 12, fats: 16, fiber: 3, servingSize: 300, servingUnit: "g", category: "lunch" },
  { nameEn: "Grilled Chicken (Half)", nameAr: "دجاجة مشوية (نص)", calories: 500, protein: 60, carbs: 0, fats: 28, fiber: 0, servingSize: 300, servingUnit: "g", category: "lunch" },
  { nameEn: "Grilled Kofta", nameAr: "كفتة مشوية", calories: 250, protein: 22, carbs: 5, fats: 16, fiber: 0, servingSize: 150, servingUnit: "g", category: "lunch" },
  { nameEn: "Grilled Kofta (Single Skewer)", nameAr: "سيخ كفتة مشوي", calories: 130, protein: 12, carbs: 2, fats: 8, fiber: 0, servingSize: 80, servingUnit: "g", category: "lunch" },
  { nameEn: "Hawawshi", nameAr: "حواوشي", calories: 420, protein: 22, carbs: 38, fats: 20, fiber: 2, servingSize: 200, servingUnit: "g", category: "lunch" },
  { nameEn: "Rice (White, Cooked)", nameAr: "أرز أبيض مطبوخ", calories: 200, protein: 4, carbs: 44, fats: 0, fiber: 1, servingSize: 150, servingUnit: "g", category: "lunch" },
  { nameEn: "Rice with Vermicelli", nameAr: "أرز بالشعرية", calories: 220, protein: 4, carbs: 46, fats: 2, fiber: 1, servingSize: 150, servingUnit: "g", category: "lunch" },
  { nameEn: "Macarona Bechamel", nameAr: "مكرونة بشاميل", calories: 380, protein: 16, carbs: 45, fats: 16, fiber: 2, servingSize: 250, servingUnit: "g", category: "lunch" },
  { nameEn: "Stuffed Grape Leaves (Warak Einab)", nameAr: "ورق عنب محشي", calories: 220, protein: 6, carbs: 28, fats: 10, fiber: 3, servingSize: 150, servingUnit: "g", category: "lunch" },
  { nameEn: "Stuffed Peppers", nameAr: "فلفل محشي", calories: 230, protein: 9, carbs: 30, fats: 9, fiber: 4, servingSize: 200, servingUnit: "g", category: "lunch" },
  { nameEn: "Daoud Basha (Meatballs in Tomato Sauce)", nameAr: "داود باشا", calories: 320, protein: 22, carbs: 18, fats: 18, fiber: 2, servingSize: 250, servingUnit: "g", category: "lunch" },
  { nameEn: "Fried Liver (Kebda)", nameAr: "كبدة مقلية", calories: 200, protein: 20, carbs: 6, fats: 11, fiber: 0, servingSize: 150, servingUnit: "g", category: "lunch" },
  { nameEn: "Fried Fish (Bouri)", nameAr: "سمك بوري مقلي", calories: 280, protein: 28, carbs: 8, fats: 15, fiber: 0, servingSize: 200, servingUnit: "g", category: "lunch" },
  { nameEn: "Grilled Fish", nameAr: "سمك مشوي", calories: 200, protein: 30, carbs: 0, fats: 9, fiber: 0, servingSize: 200, servingUnit: "g", category: "lunch" },
  { nameEn: "Chicken Shawarma", nameAr: "شاورما دجاج", calories: 480, protein: 32, carbs: 48, fats: 16, fiber: 3, servingSize: 280, servingUnit: "g", category: "lunch" },
  { nameEn: "Meat Shawarma", nameAr: "شاورما لحمة", calories: 530, protein: 30, carbs: 48, fats: 22, fiber: 3, servingSize: 280, servingUnit: "g", category: "lunch" },
  { nameEn: "Lentil Soup", nameAr: "شوربة عدس", calories: 180, protein: 9, carbs: 30, fats: 3, fiber: 7, servingSize: 250, servingUnit: "g", category: "lunch" },
  { nameEn: "Tomato Soup", nameAr: "شوربة طماطم", calories: 80, protein: 2, carbs: 14, fats: 2, fiber: 2, servingSize: 250, servingUnit: "g", category: "lunch" },

  // ── Dinner ───────────────────────────────────────────────────────────────
  { nameEn: "Egyptian Feteer (Plain)", nameAr: "فطير مشلتيت سادة", calories: 350, protein: 8, carbs: 50, fats: 14, fiber: 1, servingSize: 150, servingUnit: "g", category: "dinner" },
  { nameEn: "Feteer with Cheese", nameAr: "فطير بالجبنة", calories: 430, protein: 14, carbs: 52, fats: 20, fiber: 1, servingSize: 180, servingUnit: "g", category: "dinner" },
  { nameEn: "Kushari (Home Style)", nameAr: "كشري بيتي", calories: 380, protein: 12, carbs: 70, fats: 7, fiber: 5, servingSize: 300, servingUnit: "g", category: "dinner" },
  { nameEn: "Ful with Egg", nameAr: "فول بالبيض", calories: 290, protein: 16, carbs: 29, fats: 12, fiber: 8, servingSize: 250, servingUnit: "g", category: "dinner" },

  // ── Snacks ───────────────────────────────────────────────────────────────
  { nameEn: "Cheese Pie (Goulash)", nameAr: "جولاش بالجبنة", calories: 300, protein: 10, carbs: 30, fats: 16, fiber: 1, servingSize: 120, servingUnit: "g", category: "snack" },
  { nameEn: "Meat Pie (Goulash)", nameAr: "جولاش باللحمة", calories: 340, protein: 14, carbs: 30, fats: 19, fiber: 1, servingSize: 120, servingUnit: "g", category: "snack" },
  { nameEn: "Sambousa (Fried)", nameAr: "سمبوسة مقلية", calories: 160, protein: 5, carbs: 15, fats: 9, fiber: 1, servingSize: 60, servingUnit: "g", category: "snack" },
  { nameEn: "Basbousa", nameAr: "بسبوسة", calories: 230, protein: 4, carbs: 38, fats: 8, fiber: 1, servingSize: 100, servingUnit: "g", category: "snack" },
  { nameEn: "Om Ali", nameAr: "أم علي", calories: 400, protein: 9, carbs: 48, fats: 20, fiber: 2, servingSize: 200, servingUnit: "g", category: "snack" },
  { nameEn: "Kunafa", nameAr: "كنافة", calories: 380, protein: 7, carbs: 52, fats: 18, fiber: 1, servingSize: 150, servingUnit: "g", category: "snack" },
  { nameEn: "Qatayef", nameAr: "قطايف", calories: 200, protein: 5, carbs: 30, fats: 8, fiber: 1, servingSize: 80, servingUnit: "g", category: "snack" },
  { nameEn: "Egyptian Cookies (Kahk)", nameAr: "كحك", calories: 120, protein: 2, carbs: 16, fats: 6, fiber: 1, servingSize: 40, servingUnit: "g", category: "snack" },
  { nameEn: "Chips Ahoy (1 serving)", nameAr: "شيبس أهوي", calories: 160, protein: 2, carbs: 24, fats: 7, fiber: 1, servingSize: 36, servingUnit: "g", category: "snack" },
  { nameEn: "Potato Chips", nameAr: "شيبسي", calories: 150, protein: 2, carbs: 18, fats: 8, fiber: 1, servingSize: 30, servingUnit: "g", category: "snack" },

  // ── Drinks ───────────────────────────────────────────────────────────────
  { nameEn: "Tea with Sugar", nameAr: "شاي بالسكر", calories: 30, protein: 0, carbs: 8, fats: 0, fiber: 0, servingSize: 200, servingUnit: "ml", category: "drink" },
  { nameEn: "Tea with Milk", nameAr: "شاي باللبن", calories: 50, protein: 2, carbs: 9, fats: 1, fiber: 0, servingSize: 200, servingUnit: "ml", category: "drink" },
  { nameEn: "Turkish Coffee (No Sugar)", nameAr: "قهوة تركي سادة", calories: 5, protein: 0, carbs: 1, fats: 0, fiber: 0, servingSize: 60, servingUnit: "ml", category: "drink" },
  { nameEn: "Nescafe with Milk", nameAr: "نسكافيه باللبن", calories: 80, protein: 3, carbs: 10, fats: 3, fiber: 0, servingSize: 200, servingUnit: "ml", category: "drink" },
  { nameEn: "Fresh Orange Juice", nameAr: "عصير برتقال طازج", calories: 110, protein: 2, carbs: 26, fats: 0, fiber: 1, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Mango Juice", nameAr: "عصير مانجو", calories: 130, protein: 1, carbs: 31, fats: 0, fiber: 1, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Sugarcane Juice", nameAr: "عصير قصب", calories: 180, protein: 0, carbs: 45, fats: 0, fiber: 0, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Lemon Mint Juice", nameAr: "عصير ليمون بالنعناع", calories: 80, protein: 0, carbs: 20, fats: 0, fiber: 0, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Tamarind Juice", nameAr: "تمر هندي", calories: 120, protein: 1, carbs: 30, fats: 0, fiber: 1, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Karkadeh (Hibiscus)", nameAr: "كركديه", calories: 40, protein: 0, carbs: 10, fats: 0, fiber: 0, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Pepsi (Can 330ml)", nameAr: "بيبسي علبة", calories: 140, protein: 0, carbs: 38, fats: 0, fiber: 0, servingSize: 330, servingUnit: "ml", category: "drink" },
  { nameEn: "Pepsi (Diet, Can 330ml)", nameAr: "بيبسي دايت علبة", calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, servingSize: 330, servingUnit: "ml", category: "drink" },
  { nameEn: "Water (500ml Bottle)", nameAr: "مياه معدنية", calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, servingSize: 500, servingUnit: "ml", category: "drink" },
  { nameEn: "Milk (Full Fat)", nameAr: "لبن كامل الدسم", calories: 150, protein: 8, carbs: 12, fats: 8, fiber: 0, servingSize: 250, servingUnit: "ml", category: "drink" },
  { nameEn: "Ayran (Yogurt Drink)", nameAr: "عيران", calories: 70, protein: 4, carbs: 7, fats: 3, fiber: 0, servingSize: 250, servingUnit: "ml", category: "drink" },

  // ── Grains & Starches ────────────────────────────────────────────────────
  { nameEn: "White Rice (100g dry)", nameAr: "أرز أبيض جاف", calories: 360, protein: 7, carbs: 79, fats: 1, fiber: 1, servingSize: 100, servingUnit: "g", category: "grain" },
  { nameEn: "Brown Rice (100g dry)", nameAr: "أرز بني جاف", calories: 350, protein: 8, carbs: 73, fats: 3, fiber: 4, servingSize: 100, servingUnit: "g", category: "grain" },
  { nameEn: "Pasta (100g dry)", nameAr: "مكرونة جافة", calories: 350, protein: 13, carbs: 70, fats: 2, fiber: 3, servingSize: 100, servingUnit: "g", category: "grain" },
  { nameEn: "Oats (100g dry)", nameAr: "شوفان جاف", calories: 380, protein: 13, carbs: 67, fats: 7, fiber: 10, servingSize: 100, servingUnit: "g", category: "grain" },
  { nameEn: "Lentils (100g dry)", nameAr: "عدس جاف", calories: 350, protein: 25, carbs: 60, fats: 1, fiber: 15, servingSize: 100, servingUnit: "g", category: "grain" },
  { nameEn: "Fava Beans (Ful, 100g dry)", nameAr: "فول مجفف", calories: 340, protein: 26, carbs: 58, fats: 1, fiber: 14, servingSize: 100, servingUnit: "g", category: "grain" },

  // ── Protein Sources ──────────────────────────────────────────────────────
  { nameEn: "Chicken Breast (Grilled)", nameAr: "صدر دجاج مشوي", calories: 165, protein: 31, carbs: 0, fats: 4, fiber: 0, servingSize: 100, servingUnit: "g", category: "protein" },
  { nameEn: "Chicken Thigh (Grilled)", nameAr: "فخدة دجاج مشوية", calories: 190, protein: 26, carbs: 0, fats: 10, fiber: 0, servingSize: 100, servingUnit: "g", category: "protein" },
  { nameEn: "Beef (Lean, Cooked)", nameAr: "لحمة بتلو مطبوخة", calories: 215, protein: 26, carbs: 0, fats: 12, fiber: 0, servingSize: 100, servingUnit: "g", category: "protein" },
  { nameEn: "Ground Beef (Cooked)", nameAr: "لحمة مفرومة مطبوخة", calories: 250, protein: 24, carbs: 0, fats: 17, fiber: 0, servingSize: 100, servingUnit: "g", category: "protein" },
  { nameEn: "Canned Tuna (in water)", nameAr: "تونة معلبة بالماء", calories: 110, protein: 25, carbs: 0, fats: 1, fiber: 0, servingSize: 85, servingUnit: "g", category: "protein" },
  { nameEn: "Tuna (in oil)", nameAr: "تونة بالزيت", calories: 180, protein: 22, carbs: 0, fats: 10, fiber: 0, servingSize: 85, servingUnit: "g", category: "protein" },
  { nameEn: "Eggs (2 large)", nameAr: "بيضتين كبيرتين", calories: 156, protein: 12, carbs: 2, fats: 10, fiber: 0, servingSize: 100, servingUnit: "g", category: "protein" },
  { nameEn: "Greek Yogurt", nameAr: "زبادي يوناني", calories: 100, protein: 10, carbs: 6, fats: 3, fiber: 0, servingSize: 150, servingUnit: "g", category: "protein" },
  { nameEn: "Egyptian Yogurt (Zabadi)", nameAr: "زبادي مصري", calories: 90, protein: 5, carbs: 10, fats: 3, fiber: 0, servingSize: 150, servingUnit: "g", category: "protein" },
  { nameEn: "Whey Protein Shake (1 scoop)", nameAr: "بروتين واي (سكوب)", calories: 120, protein: 24, carbs: 3, fats: 1, fiber: 0, servingSize: 30, servingUnit: "g", category: "protein" },

  // ── Vegetables ───────────────────────────────────────────────────────────
  { nameEn: "Tomato", nameAr: "طماطم", calories: 20, protein: 1, carbs: 4, fats: 0, fiber: 1, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Cucumber", nameAr: "خيار", calories: 15, protein: 1, carbs: 3, fats: 0, fiber: 1, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Lettuce", nameAr: "خس", calories: 15, protein: 1, carbs: 2, fats: 0, fiber: 1, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Onion", nameAr: "بصل", calories: 40, protein: 1, carbs: 9, fats: 0, fiber: 2, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Potato (Boiled)", nameAr: "بطاطس مسلوقة", calories: 87, protein: 2, carbs: 20, fats: 0, fiber: 2, servingSize: 150, servingUnit: "g", category: "vegetable" },
  { nameEn: "French Fries", nameAr: "بطاطس مقلية", calories: 330, protein: 4, carbs: 42, fats: 17, fiber: 4, servingSize: 150, servingUnit: "g", category: "vegetable" },
  { nameEn: "Molokhia (Cooked)", nameAr: "ملوخية مطبوخة", calories: 40, protein: 3, carbs: 5, fats: 1, fiber: 3, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Okra (Bamia, Cooked)", nameAr: "بامية مطبوخة", calories: 40, protein: 2, carbs: 7, fats: 1, fiber: 3, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Eggplant (Cooked)", nameAr: "باذنجان مطبوخ", calories: 35, protein: 1, carbs: 7, fats: 1, fiber: 3, servingSize: 100, servingUnit: "g", category: "vegetable" },
  { nameEn: "Zucchini (Cooked)", nameAr: "كوسة مطبوخة", calories: 25, protein: 1, carbs: 4, fats: 0, fiber: 2, servingSize: 100, servingUnit: "g", category: "vegetable" },

  // ── Fruits ───────────────────────────────────────────────────────────────
  { nameEn: "Banana", nameAr: "موزة", calories: 90, protein: 1, carbs: 23, fats: 0, fiber: 3, servingSize: 100, servingUnit: "g", category: "fruit" },
  { nameEn: "Apple", nameAr: "تفاحة", calories: 70, protein: 0, carbs: 19, fats: 0, fiber: 3, servingSize: 150, servingUnit: "g", category: "fruit" },
  { nameEn: "Mango", nameAr: "مانجو", calories: 100, protein: 1, carbs: 25, fats: 0, fiber: 3, servingSize: 150, servingUnit: "g", category: "fruit" },
  { nameEn: "Guava", nameAr: "جوافة", calories: 68, protein: 3, carbs: 14, fats: 1, fiber: 5, servingSize: 100, servingUnit: "g", category: "fruit" },
  { nameEn: "Watermelon", nameAr: "بطيخ", calories: 50, protein: 1, carbs: 12, fats: 0, fiber: 1, servingSize: 200, servingUnit: "g", category: "fruit" },
  { nameEn: "Orange", nameAr: "برتقالة", calories: 60, protein: 1, carbs: 15, fats: 0, fiber: 3, servingSize: 130, servingUnit: "g", category: "fruit" },
  { nameEn: "Dates (3 pieces)", nameAr: "تمر (٣ حبات)", calories: 100, protein: 1, carbs: 27, fats: 0, fiber: 3, servingSize: 40, servingUnit: "g", category: "fruit" },
  { nameEn: "Grapes", nameAr: "عنب", calories: 70, protein: 1, carbs: 18, fats: 0, fiber: 1, servingSize: 100, servingUnit: "g", category: "fruit" },

  // ── Condiments & Oils ────────────────────────────────────────────────────
  { nameEn: "Olive Oil (1 tbsp)", nameAr: "زيت زيتون (ملعقة)", calories: 120, protein: 0, carbs: 0, fats: 14, fiber: 0, servingSize: 14, servingUnit: "g", category: "condiment" },
  { nameEn: "Sunflower Oil (1 tbsp)", nameAr: "زيت عباد الشمس (ملعقة)", calories: 120, protein: 0, carbs: 0, fats: 14, fiber: 0, servingSize: 14, servingUnit: "g", category: "condiment" },
  { nameEn: "Butter (1 tsp)", nameAr: "زبدة (ملعقة صغيرة)", calories: 36, protein: 0, carbs: 0, fats: 4, fiber: 0, servingSize: 5, servingUnit: "g", category: "condiment" },
  { nameEn: "Tomato Paste (1 tbsp)", nameAr: "صلصة طماطم (ملعقة)", calories: 13, protein: 1, carbs: 3, fats: 0, fiber: 0, servingSize: 16, servingUnit: "g", category: "condiment" },
  { nameEn: "Sugar (1 tsp)", nameAr: "سكر (ملعقة صغيرة)", calories: 16, protein: 0, carbs: 4, fats: 0, fiber: 0, servingSize: 4, servingUnit: "g", category: "condiment" },
];

// ---------------------------------------------------------------------------
// Restaurants (preserved from original seed)
// ---------------------------------------------------------------------------
const restaurants = [
  { name: "Buffalo Burger", category: "fast-food", rating: 4.6 },
  { name: "McDonald's", category: "fast-food", rating: 4.3 },
  { name: "KFC", category: "fast-food", rating: 4.5 },
  { name: "Hardee's", category: "fast-food", rating: 4.4 },
  { name: "Popeyes", category: "fast-food", rating: 4.2 },
  { name: "Cook Door", category: "fast-food", rating: 4.5 },
  { name: "Mo'men", category: "fast-food", rating: 4.4 },
  { name: "Gad", category: "fast-food", rating: 4.3 },
  { name: "Abou Tarek", category: "koshary", rating: 4.7 },
  { name: "Koshary El Tahrir", category: "koshary", rating: 4.6 },
  { name: "Kazouza", category: "koshary", rating: 4.5 },
  { name: "Arab", category: "grills", rating: 4.6 },
  { name: "Kababgy", category: "grills", rating: 4.5 },
];

async function main() {
  console.log("🌱  Seeding The Teneen database...\n");

  // ── Seed Restaurants ──────────────────────────────────────────────────────
  console.log("📍  Seeding restaurants...");
  for (const restaurant of restaurants) {
    const created = await prisma.restaurant.upsert({
      where:  { name: restaurant.name },
      update: { rating: restaurant.rating },
      create: restaurant,
    });
    console.log(`   ✅  ${created.name}`);
  }

  // ── Seed Food Items ───────────────────────────────────────────────────────
  console.log("\n🍽️   Seeding Egyptian food items...");
  let count = 0;
  for (const item of foodItems) {
    await prisma.foodItem.upsert({
      where:  { id: `seed-${item.nameEn.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "")}` },
      update: {
        calories: item.calories, protein: item.protein,
        carbs: item.carbs, fats: item.fats,
        nameAr: item.nameAr, isVerified: true,
      },
      create: {
        id:         `seed-${item.nameEn.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "")}`,
        nameEn:     item.nameEn,
        nameAr:     item.nameAr,
        calories:   item.calories,
        protein:    item.protein,
        carbs:      item.carbs,
        fats:       item.fats,
        fiber:      item.fiber,
        servingSize: item.servingSize,
        servingUnit: item.servingUnit,
        category:   item.category,
        isVerified: true,
      },
    });
    count++;
  }
  console.log(`   ✅  ${count} food items seeded`);

  console.log("\n🎉  Database seeded successfully!");
}

main()
  .catch((e) => {
    console.error("❌  Seed failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

