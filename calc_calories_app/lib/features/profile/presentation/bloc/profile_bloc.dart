// lib/features/profile/presentation/bloc/profile_bloc.dart
// The Teneen — Profile BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;

  ProfileBloc({required this.repository}) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<CheckOnboardingStatus>(_onCheckOnboardingStatus);
    on<CompleteOnboardingEvent>(_onCompleteOnboarding);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final results = await Future.wait([
      repository.fetchUserProfile(),
      repository.isOnboardingCompleted(),
    ]);

    final profileResult = results[0] as dynamic;
    final isOnboardingCompleted = results[1] as bool;

    profileResult.fold(
      (failure) => emit(ProfileFailure(failure.message)),
      (user) => emit(ProfileLoaded(
        user: user,
        isOnboardingCompleted: isOnboardingCompleted,
      )),
    );
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final result = await repository.updateProfile(
      name: event.name,
      age: event.age,
      weightKg: event.weightKg,
      heightCm: event.heightCm,
      gender: event.gender,
      activityLevel: event.activityLevel,
      goal: event.goal,
      dailyCalorieGoal: event.dailyCalorieGoal,
      dailyWaterGoalMl: event.dailyWaterGoalMl,
      language: event.language,
    );

    await result.fold(
      (failure) async => emit(ProfileFailure(failure.message)),
      (response) async {
        final user = response['user'] as Map<String, dynamic>;
        emit(ProfileUpdateSuccess(user));
        // Trigger load again to refresh UI state fully
        final isCompleted = await repository.isOnboardingCompleted();
        emit(ProfileLoaded(
          user: user,
          isOnboardingCompleted: isCompleted,
        ));
      },
    );
  }

  Future<void> _onCheckOnboardingStatus(
    CheckOnboardingStatus event,
    Emitter<ProfileState> emit,
  ) async {
    final isCompleted = await repository.isOnboardingCompleted();
    emit(OnboardingStatusChecked(isCompleted));
  }

  Future<void> _onCompleteOnboarding(
    CompleteOnboardingEvent event,
    Emitter<ProfileState> emit,
  ) async {
    await repository.setOnboardingCompleted(true);
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(ProfileLoaded(
        user: currentState.user,
        isOnboardingCompleted: true,
      ));
    } else if (currentState is ProfileUpdateSuccess) {
      emit(ProfileLoaded(
        user: currentState.user,
        isOnboardingCompleted: true,
      ));
    } else {
      final result = await repository.fetchUserProfile();
      result.fold(
        (failure) => emit(ProfileFailure(failure.message)),
        (user) => emit(ProfileLoaded(
          user: user,
          isOnboardingCompleted: true,
        )),
      );
    }
  }
}
