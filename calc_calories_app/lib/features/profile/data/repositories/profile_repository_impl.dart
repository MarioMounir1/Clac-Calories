// lib/features/profile/data/repositories/profile_repository_impl.dart
// The Teneen — Profile Repository Implementation

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient apiClient;
  static const _onboardingKey = 'onboarding_completed';

  ProfileRepositoryImpl(this.apiClient);

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateProfile({
    String? name,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    String? activityLevel,
    String? goal,
    int? dailyCalorieGoal,
    int? dailyWaterGoalMl,
    String? language,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (age != null) data['age'] = age;
      if (weightKg != null) data['weightKg'] = weightKg;
      if (heightCm != null) data['heightCm'] = heightCm;
      if (gender != null) data['gender'] = gender;
      if (activityLevel != null) data['activityLevel'] = activityLevel;
      if (goal != null) data['goal'] = goal;
      if (dailyCalorieGoal != null) data['dailyCalorieGoal'] = dailyCalorieGoal;
      if (dailyWaterGoalMl != null) data['dailyWaterGoalMl'] = dailyWaterGoalMl;
      if (language != null) data['language'] = language;

      final response = await apiClient.dio.put('/users/profile', data: data);
      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        return Right(body);
      }
      return const Left(ServerFailure(message: 'Failed to update profile'));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final msg = e.response?.data?['error'] ?? 'Server error occurred during profile update';
      return Left(ServerFailure(message: msg.toString()));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> fetchUserProfile() async {
    try {
      final response = await apiClient.dio.get('/users/me');
      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return Right(body['data']['user'] as Map<String, dynamic>);
        }
      }
      return const Left(ServerFailure(message: 'Failed to fetch user profile'));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final msg = e.response?.data?['error'] ?? 'Server error occurred during fetch';
      return Left(ServerFailure(message: msg.toString()));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getTdee() async {
    try {
      final response = await apiClient.dio.get('/users/tdee');
      if (response.statusCode == 200) {
        return Right(response.data as Map<String, dynamic>);
      }
      return const Left(ServerFailure(message: 'Failed to fetch TDEE'));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final msg = e.response?.data?['error'] ?? 'Server error occurred during TDEE calculation';
      return Left(ServerFailure(message: msg.toString()));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }
}
