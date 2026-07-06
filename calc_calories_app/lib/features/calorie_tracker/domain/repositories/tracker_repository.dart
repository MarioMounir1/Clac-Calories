// lib/features/calorie_tracker/domain/repositories/tracker_repository.dart
// The Teneen — Unified Nutrition & Tracker Repository Interface

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class TrackerRepository {
  // ── Food Log ──
  Future<Either<Failure, Map<String, dynamic>>> getTodayFoodSummary({String? date});
  Future<Either<Failure, Map<String, dynamic>>> searchFoods({
    required String query,
    String? category,
    int? limit,
    int? page,
  });
  Future<Either<Failure, Map<String, dynamic>>> getFoodCategories();
  Future<Either<Failure, Map<String, dynamic>>> logFood({
    required String foodItemId,
    required double servings,
    required String mealType,
    String? loggedAt,
  });
  Future<Either<Failure, void>> deleteFoodLog(String id);

  // ── Manual Meal Log ──
  Future<Either<Failure, Map<String, dynamic>>> logManualMeal({
    String? mealName,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? mealType,
  });

  // ── Water ──
  Future<Either<Failure, Map<String, dynamic>>> getTodayWater({String? date});
  Future<Either<Failure, Map<String, dynamic>>> logWater({required int amountMl});
  Future<Either<Failure, void>> deleteWaterLog(String id);

  // ── Weight ──
  Future<Either<Failure, Map<String, dynamic>>> getWeightHistory({int days = 30});
  Future<Either<Failure, Map<String, dynamic>>> logWeight({required double weightKg});
  Future<Either<Failure, void>> deleteWeightLog(String id);

  // ── Meal Plan ──
  Future<Either<Failure, Map<String, dynamic>>> getTodayMealPlan();
  Future<Either<Failure, Map<String, dynamic>>> getWeekMealPlan();
  Future<Either<Failure, Map<String, dynamic>>> generateWeeklyMealPlan();
  Future<Either<Failure, Map<String, dynamic>>> toggleMealPlanEaten({
    required String id,
    required bool isEaten,
  });
}
