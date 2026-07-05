// lib/features/calorie_tracker/presentation/food_search_screen.dart
// The Teneen — Food Database Search and Log Screen

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'bloc/food_search_bloc.dart';
import 'bloc/food_search_event.dart';
import 'bloc/food_search_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.read<FoodSearchBloc>().add(SearchFoodsEvent(query: val));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.foodSearchTitle),
        centerTitle: false,
      ),
      body: BlocListener<FoodSearchBloc, FoodSearchState>(
        listener: (context, state) {
          if (state is FoodLogSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.foodLoggedSuccess),
                backgroundColor: AppColors.primary,
              ),
            );
            // Refresh dashboard data so main ring updates immediately
            context.read<DashboardBloc>().add(const RefreshDashboard());
          } else if (state is FoodSearchFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: Column(
          children: [
            // ── Search Input Box ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextFormField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: l10n.foodSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),

            // ── Category List & Results ─────────────────────────────
            Expanded(
              child: BlocBuilder<FoodSearchBloc, FoodSearchState>(
                builder: (context, state) {
                  if (state is FoodSearchInitial) {
                    context.read<FoodSearchBloc>().add(LoadFoodCategories());
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is FoodSearchLoading && _searchController.text.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is FoodSearchLoaded) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categories horizontal list
                        SizedBox(
                          height: 48,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.categories.length,
                            itemBuilder: (context, index) {
                              final cat = state.categories[index];
                              final String categoryCode = cat['category'];
                              final label = cat['label'] as Map<String, dynamic>;
                              final String categoryName = isArabic ? label['ar'] : label['en'];
                              final count = cat['count'];

                              final isSelected = state.activeCategory == categoryCode;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$categoryName ($count)'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    context.read<FoodSearchBloc>().add(
                                          SelectCategoryEvent(
                                            category: categoryCode,
                                            query: _searchController.text,
                                          ),
                                        );
                                  },
                                  selectedColor: AppColors.primary.withOpacity(0.15),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Search Results list
                        Expanded(
                          child: state.items.isEmpty
                              ? _buildEmptyState(state.activeQuery, l10n)
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: state.items.length,
                                  itemBuilder: (context, index) {
                                    final item = state.items[index];
                                    final String name = isArabic ? item['nameAr'] : item['nameEn'];
                                    final double cal = (item['calories'] as num).toDouble();
                                    final double size = (item['servingSize'] as num).toDouble();
                                    final String unit = item['servingUnit'];
                                    final bool isVerified = item['isVerified'] == true;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.border),
                                        color: AppColors.surface,
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                              ),
                                            ),
                                            if (isVerified)
                                              const Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.foodServingSize(size, unit),
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _buildMacroLabel('P: ${item['protein']}g', AppColors.protein),
                                                const SizedBox(width: 8),
                                                _buildMacroLabel('C: ${item['carbs']}g', AppColors.carbs),
                                                const SizedBox(width: 8),
                                                _buildMacroLabel('F: ${item['fats']}g', AppColors.fats),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              l10n.foodCaloriesPer(cal),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 4),
                                            const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                                          ],
                                        ),
                                        onTap: () => _showLogDialog(context, item, name, l10n),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query, AppLocalizations l10n) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              l10n.foodSearchHint,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            l10n.foodSearchNoResults(query),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withOpacity(0.12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showLogDialog(BuildContext context, Map<String, dynamic> item, String name, AppLocalizations l10n) {
    double servings = 1.0;
    String mealType = 'lunch';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stateContext, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.foodSelectServings,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primary, size: 28),
                            onPressed: () {
                              if (servings > 0.1) {
                                setModalState(() => servings = (servings - 0.1).clamp(0.1, 50.0));
                              }
                            },
                          ),
                          Text(
                            servings.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 28),
                            onPressed: () {
                              setModalState(() => servings = (servings + 0.1).clamp(0.1, 50.0));
                            },
                          ),
                        ],
                      ),
                      Text(
                        l10n.foodCaloriesPer(double.parse(((item['calories'] as num) * servings).toStringAsFixed(1))),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                      final isActive = mealType == type;

                      // Localized labels
                      String label = type;
                      if (type == 'breakfast') label = l10n.mealTypeBreakfast;
                      else if (type == 'lunch') label = l10n.mealTypeLunch;
                      else if (type == 'dinner') label = l10n.mealTypeDinner;
                      else if (type == 'snack') label = l10n.mealTypeSnack;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            onPressed: () => setModalState(() => mealType = type),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isActive ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                              side: BorderSide(color: isActive ? AppColors.primary : AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<FoodSearchBloc>().add(
                              LogFoodItemEvent(
                                foodItemId: item['id'],
                                servings: servings,
                                mealType: mealType,
                              ),
                            );
                        Navigator.pop(sheetContext);
                      },
                      child: Text(l10n.foodLogButton),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
