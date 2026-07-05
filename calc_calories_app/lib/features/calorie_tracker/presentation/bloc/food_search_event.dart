// lib/features/calorie_tracker/presentation/bloc/food_search_event.dart
// The Teneen — Food Search Events

import 'package:equatable/equatable.dart';

abstract class FoodSearchEvent extends Equatable {
  const FoodSearchEvent();

  @override
  List<Object?> get props => [];
}

class LoadFoodCategories extends FoodSearchEvent {}

class SearchFoodsEvent extends FoodSearchEvent {
  final String query;
  final String? category;

  const SearchFoodsEvent({required this.query, this.category});

  @override
  List<Object?> get props => [query, category];
}

class SelectCategoryEvent extends FoodSearchEvent {
  final String? category;
  final String query;

  const SelectCategoryEvent({this.category, required this.query});

  @override
  List<Object?> get props => [category, query];
}

class LogFoodItemEvent extends FoodSearchEvent {
  final String foodItemId;
  final double servings;
  final String mealType;

  const LogFoodItemEvent({
    required this.foodItemId,
    required this.servings,
    required this.mealType,
  });

  @override
  List<Object?> get props => [foodItemId, servings, mealType];
}
