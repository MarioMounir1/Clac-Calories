import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../../../core/network/api_client.dart';
import '../../../premium/data/services/purchase_service.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;
  StreamSubscription? _premiumSubscription;
  bool _isProfileInFlight = false;

  ProfileBloc({required this.repository}) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile, transformer: restartable());
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<CheckOnboardingStatus>(_onCheckOnboardingStatus);
    on<CompleteOnboardingEvent>(_onCompleteOnboarding);
    on<UpdatePremiumStatus>(_onUpdatePremiumStatus);
    on<ResetProfileEvent>((event, emit) {
      _isProfileInFlight = false;
      emit(ProfileInitial());
    });

    _premiumSubscription = PurchaseService.instance.premiumStream.listen((isPremium) {
      add(UpdatePremiumStatus(isPremium));
    });
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    if (_isProfileInFlight) {
      print('⚠️ WARNING [ProfileBloc]: LoadProfile dispatched while another LoadProfile is already in flight! Cancelling previous request via restartable().');
    }
    _isProfileInFlight = true;
    emit(ProfileLoading());
    try {
      final results = await Future.wait([
        repository.fetchUserProfile(),
        repository.isOnboardingCompleted(),
      ]);

    final profileResult = results[0] as dynamic;
    final isOnboardingCompleted = results[1] as bool;

    profileResult.fold(
      (failure) {
        print("DEBUG [ProfileBloc]: Fetch user profile failed: ${failure.message}");
        emit(ProfileFailure(failure.message));
      },
      (user) {
        final ageVal = user['age'];
        final weightVal = user['weightKg'];
        final heightVal = user['heightCm'];
        final userId = user['id'] as String? ?? '';
        
        // Sync isPremium status from backend DB to memory and local storage
        final bool isDbPremium = user['isPremium'] == true;
        ApiClient().saveIsPremium(isDbPremium);
        PurchaseService.instance.setMockPremiumStatus(isDbPremium);

        // Log into RevenueCat with the user's ID & sync entitlement status
        if (userId.isNotEmpty) {
          PurchaseService.instance.logIn(userId);
        } else {
          PurchaseService.instance.syncCustomerInfoOnLaunch();
        }

        print("DEBUG [ProfileBloc]: fetched user Map: $user");
        print("DEBUG [ProfileBloc]: isOnboardingCompleted (local): $isOnboardingCompleted");
        print("DEBUG [ProfileBloc]: ageVal: $ageVal, weightVal: $weightVal, heightVal: $heightVal");

        // Automatically determine onboarding complete if they have basic info set in the DB
        final bool actuallyCompleted = isOnboardingCompleted ||
            (ageVal != null && weightVal != null && heightVal != null);

        print("DEBUG [ProfileBloc]: actuallyCompleted resolved to: $actuallyCompleted");

        // If it was true in DB but false in local prefs, sync it back to local prefs
        if (actuallyCompleted && !isOnboardingCompleted) {
          repository.setOnboardingCompleted(true);
        }

        emit(ProfileLoaded(
          user: user,
          isOnboardingCompleted: actuallyCompleted,
        ));
      },
    );
    } finally {
      _isProfileInFlight = false;
    }
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
      targetWeightKg: event.targetWeightKg,
      gender: event.gender,
      activityLevel: event.activityLevel,
      goal: event.goal,
      trainingExperience: event.trainingExperience,
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
        final bool isLocalCompleted = await repository.isOnboardingCompleted();
        final bool actuallyCompleted = isLocalCompleted ||
            (user['age'] != null && user['weightKg'] != null && user['heightCm'] != null);

        if (actuallyCompleted && !isLocalCompleted) {
          await repository.setOnboardingCompleted(true);
        }

        emit(ProfileLoaded(
          user: user,
          isOnboardingCompleted: actuallyCompleted,
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

  void _onUpdatePremiumStatus(
    UpdatePremiumStatus event,
    Emitter<ProfileState> emit,
  ) {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      if (currentState.user['isPremium'] == event.isPremium) return;
      final updatedUser = Map<String, dynamic>.from(currentState.user);
      updatedUser['isPremium'] = event.isPremium;
      emit(ProfileLoaded(
        user: updatedUser,
        isOnboardingCompleted: currentState.isOnboardingCompleted,
      ));
    }
  }

  @override
  Future<void> close() {
    _premiumSubscription?.cancel();
    return super.close();
  }
}
