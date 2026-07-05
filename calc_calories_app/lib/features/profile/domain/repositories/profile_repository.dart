// lib/features/profile/domain/repositories/profile_repository.dart
// The Teneen — Profile Repository Interface

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class ProfileRepository {
  /// Update user physical profile and return updated user object
  Future<Either<Failure, Map<String, dynamic>>> updateProfile({
    String? name,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender, // male | female
    String? activityLevel, // sedentary | lightly_active | moderate | very_active
    String? goal, // lose | maintain | gain
    int? dailyCalorieGoal,
    int? dailyWaterGoalMl,
    String? language, // en | ar
  });

  /// Fetch the current user profile from the backend (/users/me)
  Future<Either<Failure, Map<String, dynamic>>> fetchUserProfile();

  /// Fetch TDEE calculation details for the current user
  Future<Either<Failure, Map<String, dynamic>>> getTdee();

  /// Check if onboarding is completed locally
  Future<bool> isOnboardingCompleted();

  /// Set onboarding completed locally
  Future<void> setOnboardingCompleted(bool completed);
}
