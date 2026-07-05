// lib/features/calorie_tracker/presentation/bloc/food_search_state.dart
// The Teneen — Food Search States

import 'package:equatable/equatable.dart';

abstract class FoodSearchState extends Equatable {
  const FoodSearchState();

  @override
  List<Object?> get props => [];
}

class FoodSearchInitial extends FoodSearchState {}

class FoodSearchLoading extends FoodSearchState {}

class FoodSearchLoaded extends FoodSearchState {
  final List<dynamic> categories;
  final List<dynamic> items;
  final String? activeCategory;
  final String activeQuery;

  const FoodSearchLoaded({
    required this.categories,
    required this.items,
    this.activeCategory,
    required this.activeQuery,
  });

  FoodSearchLoaded copyWith({
    List<dynamic>? categories,
    List<dynamic>? items,
    String? activeCategory,
    bool clearCategory = false,
    String? activeQuery,
  }) {
    return FoodSearchLoaded(
      categories: categories ?? this.categories,
      items: items ?? this.items,
      activeCategory: clearCategory ? null : (activeCategory ?? this.activeCategory),
      activeQuery: activeQuery ?? this.activeQuery,
    );
  }

  @override
  List<Object?> get props => [categories, items, activeCategory, activeQuery];
}

class FoodLogSuccess extends FoodSearchState {
  final String message;
  const FoodLogSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class FoodSearchFailure extends FoodSearchState {
  final String message;
  const FoodSearchFailure(this.message);

  @override
  List<Object?> get props => [message];
}
