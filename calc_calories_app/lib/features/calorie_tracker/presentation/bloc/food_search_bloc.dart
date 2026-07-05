// lib/features/calorie_tracker/presentation/bloc/food_search_bloc.dart
// The Teneen — Food Search BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/tracker_repository.dart';
import 'food_search_event.dart';
import 'food_search_state.dart';

class FoodSearchBloc extends Bloc<FoodSearchEvent, FoodSearchState> {
  final TrackerRepository repository;

  FoodSearchBloc({required this.repository}) : super(FoodSearchInitial()) {
    on<LoadFoodCategories>(_onLoadFoodCategories);
    on<SearchFoodsEvent>(_onSearchFoods);
    on<SelectCategoryEvent>(_onSelectCategory);
    on<LogFoodItemEvent>(_onLogFoodItem);
  }

  Future<void> _onLoadFoodCategories(
    LoadFoodCategories event,
    Emitter<FoodSearchState> emit,
  ) async {
    emit(FoodSearchLoading());
    final result = await repository.getFoodCategories();
    result.fold(
      (failure) => emit(FoodSearchFailure(failure.message)),
      (data) {
        final categories = data['categories'] as List<dynamic>? ?? [];
        emit(FoodSearchLoaded(
          categories: categories,
          items: const [],
          activeQuery: '',
        ));
      },
    );
  }

  Future<void> _onSearchFoods(
    SearchFoodsEvent event,
    Emitter<FoodSearchState> emit,
  ) async {
    final currentState = state;
    List<dynamic> categories = const [];
    String? activeCategory;

    if (currentState is FoodSearchLoaded) {
      categories = currentState.categories;
      activeCategory = currentState.activeCategory;
    } else {
      emit(FoodSearchLoading());
      final catResult = await repository.getFoodCategories();
      catResult.fold(
        (failure) {},
        (data) => categories = data['categories'] as List<dynamic>? ?? [],
      );
    }

    if (event.query.trim().isEmpty) {
      emit(FoodSearchLoaded(
        categories: categories,
        items: const [],
        activeCategory: activeCategory,
        activeQuery: event.query,
      ));
      return;
    }

    emit(FoodSearchLoading());
    final searchResult = await repository.searchFoods(
      query: event.query,
      category: event.category ?? activeCategory,
    );

    searchResult.fold(
      (failure) => emit(FoodSearchFailure(failure.message)),
      (data) {
        final items = data['items'] as List<dynamic>? ?? [];
        emit(FoodSearchLoaded(
          categories: categories,
          items: items,
          activeCategory: event.category ?? activeCategory,
          activeQuery: event.query,
        ));
      },
    );
  }

  Future<void> _onSelectCategory(
    SelectCategoryEvent event,
    Emitter<FoodSearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is FoodSearchLoaded) {
      final isTogglingOff = currentState.activeCategory == event.category;
      final newCategory = isTogglingOff ? null : event.category;

      emit(FoodSearchLoading());

      if (event.query.trim().isEmpty) {
        emit(FoodSearchLoaded(
          categories: currentState.categories,
          items: const [],
          activeCategory: newCategory,
          activeQuery: event.query,
        ));
        return;
      }

      final searchResult = await repository.searchFoods(
        query: event.query,
        category: newCategory,
      );

      searchResult.fold(
        (failure) => emit(FoodSearchFailure(failure.message)),
        (data) {
          final items = data['items'] as List<dynamic>? ?? [];
          emit(FoodSearchLoaded(
            categories: currentState.categories,
            items: items,
            activeCategory: newCategory,
            activeQuery: event.query,
          ));
        },
      );
    }
  }

  Future<void> _onLogFoodItem(
    LogFoodItemEvent event,
    Emitter<FoodSearchState> emit,
  ) async {
    final currentState = state;
    emit(FoodSearchLoading());
    final result = await repository.logFood(
      foodItemId: event.foodItemId,
      servings: event.servings,
      mealType: event.mealType,
    );

    result.fold(
      (failure) => emit(FoodSearchFailure(failure.message)),
      (data) {
        emit(const FoodLogSuccess('Food logged successfully'));
        // Restore search results so search UI remains intact
        if (currentState is FoodSearchLoaded) {
          emit(currentState);
        } else {
          add(LoadFoodCategories());
        }
      },
    );
  }
}
