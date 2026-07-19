// lib/features/calorie_tracker/data/repositories/meal_repository_impl.dart
// Calc-Calories — Repository Implementation (network-first, Hive fallback)

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/constants.dart';
import '../../domain/entities/meal_log_entity.dart';
import '../../domain/repositories/meal_repository.dart';
import '../models/meal_log_model.dart';

class MealRepositoryImpl implements MealRepository {
  final ApiClient _apiClient;

  MealRepositoryImpl(this._apiClient);

  // ── Analyze Text Meal ──────────────────────────────────

  @override
  Future<Either<Failure, MealLogEntity>> analyzeTextMeal({
    required String restaurantName,
    required String mealDescription,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/meals/analyze',
        data: {
          'restaurantName': restaurantName,
          'mealDescription': mealDescription,
        },
      );

      final model = MealLogModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );

      // Cache locally for offline access
      await _saveToHive(model);

      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ── Analyze Image Meal ─────────────────────────────────

  @override
  Future<Either<Failure, MealLogEntity>> analyzeImageMeal({
    required String imagePath,
    String? restaurantName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: 'meal_screenshot.jpg',
        ),
        if (restaurantName != null && restaurantName.isNotEmpty)
          'restaurantName': restaurantName,
      });

      final response = await _apiClient.dio.post(
        '/meals/analyze',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 90), // Longer for image processing
        ),
      );

      final model = MealLogModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );

      await _saveToHive(model);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ── Get Meal History ───────────────────────────────────

  @override
  Future<Either<Failure, List<MealLogEntity>>> getMealHistory({
    int page = 1,
    int limit = 20,
    String? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (date != null) 'date': date,
      };

      final response = await _apiClient.dio.get(
        '/meals/history',
        queryParameters: queryParams,
      );

      final rawLogs = response.data['data']['logs'] as List<dynamic>;
      final models = rawLogs
          .whereType<Map<String, dynamic>>()
          .map(MealLogModel.fromJson)
          .toList();

      // Update Hive cache with fresh data (first page only)
      if (page == 1) {
        await _refreshHiveCache(models);
      }

      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      // Network error — fall back to Hive cache
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return getCachedMealLogs();
      }
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ── Delete Meal Log ────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteMealLog(String id) async {
    try {
      await _apiClient.dio.delete('/meals/$id');

      // Also remove from Hive cache
      final box = Hive.box<MealLogModel>(AppConstants.mealLogsBox);
      final keyToDelete = box.keys.firstWhere(
        (k) => box.get(k)?.id == id,
        orElse: () => null,
      );
      if (keyToDelete != null) {
        await box.delete(keyToDelete);
      }

      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ── Hive Cache Operations ──────────────────────────────

  @override
  Future<Either<Failure, List<MealLogEntity>>> getCachedMealLogs() async {
    try {
      final box = Hive.box<MealLogModel>(AppConstants.mealLogsBox);
      final models = box.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to read local cache: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> cacheMealLog(MealLogEntity mealLog) async {
    try {
      await _saveToHive(MealLogModel.fromEntity(mealLog));
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to save to local cache: ${e.toString()}'));
    }
  }

  // ── Private Helpers ────────────────────────────────────

  Future<void> _saveToHive(MealLogModel model) async {
    try {
      final box = Hive.box<MealLogModel>(AppConstants.mealLogsBox);
      await box.add(model);
      // Keep only the last 200 entries
      if (box.length > 200) {
        await box.deleteAt(0);
      }
    } catch (_) {
      // Hive write failure is non-critical
    }
  }

  Future<void> _refreshHiveCache(List<MealLogModel> models) async {
    try {
      final box = Hive.box<MealLogModel>(AppConstants.mealLogsBox);
      await box.clear();
      await box.addAll(models);
    } catch (_) {
      // Non-critical
    }
  }

  Failure _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;
    final serverMessage =
        responseData is Map ? responseData['error'] as String? : null;

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure();
      default:
        break;
    }

    if (statusCode == 401) {
      return const AuthFailure();
    }
    if (statusCode == 429) {
      final retryAfter = responseData is Map
          ? responseData['retryAfter'] as int?
          : null;
      return RateLimitFailure(retryAfterSeconds: retryAfter);
    }
    if (statusCode == 400) {
      return ValidationFailure(message: serverMessage ?? 'Invalid request.');
    }
    if (statusCode == 502 || statusCode == 503) {
      return ServerFailure(
        message: serverMessage ?? 'AI service temporarily unavailable.',
        code: 'AI_ERROR',
      );
    }

    return ServerFailure(
      message: serverMessage ?? 'An unexpected error occurred.',
      code: statusCode?.toString(),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSuggestions() async {
    try {
      final response = await _apiClient.dio.get('/meals/suggestions');
      return Right(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
