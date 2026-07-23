// lib/features/calorie_tracker/presentation/bloc/dashboard_bloc.dart
// The Teneen — Dashboard BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../domain/entities/meal_log_entity.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/tracker_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final TrackerRepository repository;
  final MealRepository? mealRepository;
  bool _isFetchInFlight = false;

  DashboardBloc({
    required this.repository,
    this.mealRepository,
  }) : super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard, transformer: restartable());
    on<RefreshDashboard>(_onRefreshDashboard);
    on<ResetDashboardEvent>((event, emit) {
      _isFetchInFlight = false;
      emit(DashboardInitial());
    });
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    if (_isFetchInFlight) {
      print('⚠️ WARNING [DashboardBloc]: LoadDashboard dispatched while another LoadDashboard is already in flight! Cancelling previous request via restartable().');
    }
    _isFetchInFlight = true;
    emit(DashboardLoading());
    try {
      await _fetchData(event.date, emit);
    } finally {
      _isFetchInFlight = false;
    }
  }

  Future<void> _onRefreshDashboard(
    RefreshDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    await _fetchData(event.date, emit);
  }

  Future<void> _fetchData(String? date, Emitter<DashboardState> emit) async {
    final dateStr = date ?? DateTime.now().toIso8601String().split('T')[0];

    final results = await Future.wait([
      repository.getTodayFoodSummary(date: dateStr),
      repository.getTodayWater(date: dateStr),
      repository.getWeightHistory(days: 7),
      repository.getTodayMealPlan(),
      if (mealRepository != null)
        mealRepository!.getMealHistory(date: dateStr)
      else
        Future.value(null),
    ]);

    final foodRes = results[0] as dynamic;
    final waterRes = results[1] as dynamic;
    final weightRes = results[2] as dynamic;
    final mealPlanRes = results[3] as dynamic;
    final mealHistoryRes = results[4] as dynamic;

    String? errorMsg;
    Map<String, dynamic>? foodData;
    Map<String, dynamic>? waterData;
    Map<String, dynamic>? weightData;
    Map<String, dynamic>? mealPlanData;
    List<MealLogEntity>? mealHistoryLogs;

    foodRes.fold(
      (failure) => errorMsg = failure.message,
      (data) => foodData = data,
    );

    waterRes.fold(
      (failure) => errorMsg ??= failure.message,
      (data) => waterData = data,
    );

    weightRes.fold(
      (failure) => errorMsg ??= failure.message,
      (data) => weightData = data,
    );

    mealPlanRes.fold(
      (failure) => errorMsg ??= failure.message,
      (data) => mealPlanData = data,
    );

    if (mealHistoryRes != null) {
      mealHistoryRes.fold(
        (failure) => null, // Ignore history errors, fallback to foodSummary entries
        (logs) => mealHistoryLogs = logs as List<MealLogEntity>,
      );
    }

    if (foodData != null && waterData != null && weightData != null && mealPlanData != null) {
      final todayMealLogs = _parseCombinedMealLogs(foodData, mealHistoryLogs);

      emit(DashboardLoaded(
        foodSummary: foodData!,
        waterSummary: waterData!,
        weightSummary: weightData!,
        mealPlanSummary: mealPlanData!,
        todayMealLogs: todayMealLogs,
        date: dateStr,
      ));
    } else {
      emit(DashboardFailure(errorMsg ?? 'Failed to load dashboard data'));
    }
  }

  List<MealLogEntity> _parseCombinedMealLogs(
    Map<String, dynamic>? foodSummary,
    List<MealLogEntity>? historyLogs,
  ) {
    final Map<String, MealLogEntity> map = {};

    if (historyLogs != null) {
      for (final log in historyLogs) {
        final key = log.id ?? '${log.mealName}_${log.createdAt.millisecondsSinceEpoch}';
        map[key] = log;
      }
    }

    final entries = foodSummary?['entries'];
    if (entries is List) {
      for (final item in entries) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String?;
          final key = id ?? '${item['mealName']}_${item['loggedAt']}';

          if (!map.containsKey(key)) {
            final type = item['type'] as String?;
            final nutrition = item['nutrition'] as Map<String, dynamic>? ?? {};

            String mealName = 'Log';
            String restaurantName = 'Logged Meal';
            String source = 'manual';

            if (type == 'food_db') {
              final foodItem = item['foodItem'] as Map<String, dynamic>?;
              mealName = foodItem?['nameEn'] as String? ?? foodItem?['nameAr'] as String? ?? 'Food Item';
              restaurantName = 'Food Database';
              source = 'db';
            } else if (type == 'ai_scan') {
              mealName = item['mealName'] as String? ?? 'Meal Log';
              restaurantName = (item['restaurantName'] as String?)?.isNotEmpty == true
                  ? item['restaurantName'] as String
                  : 'Smart Scanner';
              source = item['source'] as String? ?? 'image';
            }

            final createdAtStr = item['loggedAt'] as String?;
            final createdAt = createdAtStr != null
                ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
                : DateTime.now();

            map[key] = MealLogEntity(
              id: id,
              restaurantName: restaurantName,
              mealName: mealName,
              calories: (nutrition['calories'] as num?)?.toDouble() ?? 0.0,
              protein: (nutrition['protein'] as num?)?.toDouble() ?? 0.0,
              carbs: (nutrition['carbs'] as num?)?.toDouble() ?? 0.0,
              fats: (nutrition['fats'] as num?)?.toDouble() ?? 0.0,
              ingredientsBreakdown: const [],
              source: source,
              createdAt: createdAt,
            );
          }
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
