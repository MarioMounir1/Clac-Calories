// lib/features/calorie_tracker/data/repositories/tracker_repository_impl.dart
// The Teneen — Unified Nutrition & Tracker Repository Implementation

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/tracker_repository.dart';

class TrackerRepositoryImpl implements TrackerRepository {
  final ApiClient apiClient;

  TrackerRepositoryImpl(this.apiClient);

  // Helper for consistent error handling
  Failure _handleError(dynamic e, String defaultMsg) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return const NetworkFailure();
      }
      final msg = e.response?.data?['error'] ?? defaultMsg;
      return ServerFailure(message: msg.toString());
    }
    return ServerFailure(message: e.toString());
  }

  // ── Food Log ──

  @override
  Future<Either<Failure, Map<String, dynamic>>> getTodayFoodSummary({String? date}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) queryParams['date'] = date;
      final response = await apiClient.dio.get('/food-logs/today', queryParameters: queryParams);
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to fetch food summary'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> searchFoods({
    required String query,
    String? category,
    int? limit,
    int? page,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'q': query,
        if (category != null) 'category': category,
        if (limit != null) 'limit': limit,
        if (page != null) 'page': page,
      };
      final response = await apiClient.dio.get('/foods/search', queryParameters: queryParams);
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to search foods'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getFoodCategories() async {
    try {
      final response = await apiClient.dio.get('/foods/categories');
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to fetch food categories'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> logFood({
    required String foodItemId,
    required double servings,
    required String mealType,
    String? loggedAt,
  }) async {
    try {
      final data = {
        'foodItemId': foodItemId,
        'servings': servings,
        'mealType': mealType,
        if (loggedAt != null) 'loggedAt': loggedAt,
      };
      final response = await apiClient.dio.post('/food-logs', data: data);
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to log food'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFoodLog(String id) async {
    try {
      await apiClient.dio.delete('/food-logs/$id');
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e, 'Failed to delete food log'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> logManualMeal({
    String? mealName,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? mealType,
  }) async {
    try {
      final data = {
        'mealName': mealName ?? 'Custom meal',
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        if (mealType != null) 'mealType': mealType,
      };
      final response = await apiClient.dio.post('/meals/manual', data: data);
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to log meal'));
    }
  }

  // ── Water ──

  @override
  Future<Either<Failure, Map<String, dynamic>>> getTodayWater({String? date}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) queryParams['date'] = date;
      final response = await apiClient.dio.get('/water/today', queryParameters: queryParams);
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to fetch water logs'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> logWater({required int amountMl}) async {
    try {
      final response = await apiClient.dio.post('/water', data: {'amountMl': amountMl});
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to log water'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWaterLog(String id) async {
    try {
      await apiClient.dio.delete('/water/$id');
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e, 'Failed to delete water log'));
    }
  }

  // ── Weight ──

  @override
  Future<Either<Failure, Map<String, dynamic>>> getWeightHistory({int days = 30}) async {
    try {
      final response = await apiClient.dio.get('/weight/history', queryParameters: {'days': days});
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to fetch weight history'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> logWeight({required double weightKg}) async {
    try {
      final response = await apiClient.dio.post('/weight', data: {'weightKg': weightKg});
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to log weight'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWeightLog(String id) async {
    try {
      await apiClient.dio.delete('/weight/$id');
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e, 'Failed to delete weight log'));
    }
  }

  // ── Meal Plan ──

  @override
  Future<Either<Failure, Map<String, dynamic>>> getTodayMealPlan() async {
    try {
      final response = await apiClient.dio.get('/meal-plans/today');
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to fetch today\'s meal plan'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getWeekMealPlan() async {
    try {
      final response = await apiClient.dio.get('/meal-plans/week');
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to fetch weekly meal plan'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> generateWeeklyMealPlan() async {
    try {
      final response = await apiClient.dio.post('/meal-plans/generate');
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to generate weekly meal plan'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> toggleMealPlanEaten({
    required String id,
    required bool isEaten,
  }) async {
    try {
      final response = await apiClient.dio.put('/meal-plans/$id/eaten', data: {'isEaten': isEaten});
      return Right(response.data as Map<String, dynamic>);
    } catch (e) {
      return Left(_handleError(e, 'Failed to update meal plan status'));
    }
  }
}
