// lib/features/calorie_tracker/presentation/water_tracking_screen.dart
// The Teneen — Daily Water Tracking & Wave Progress UI

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'bloc/water_bloc.dart';
import 'bloc/water_event.dart';
import 'bloc/water_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';

class WaterTrackingScreen extends StatefulWidget {
  const WaterTrackingScreen({super.key});

  @override
  State<WaterTrackingScreen> createState() => _WaterTrackingScreenState();
}

class _WaterTrackingScreenState extends State<WaterTrackingScreen> {
  final _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.waterTitle),
        centerTitle: false,
      ),
      body: BlocListener<WaterBloc, WaterState>(
        listener: (context, state) {
          if (state is WaterLogSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.primary),
            );
            // Refresh main dashboard metrics
            context.read<DashboardBloc>().add(const RefreshDashboard());
          } else if (state is WaterFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        child: BlocBuilder<WaterBloc, WaterState>(
          builder: (context, state) {
            if (state is WaterInitial) {
              context.read<WaterBloc>().add(const LoadWaterToday());
              return const Center(child: CircularProgressIndicator());
            }
            if (state is WaterLoading && state is! WaterLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is WaterLoaded) {
              return _buildContent(context, state, l10n);
            }
            if (state is WaterFailure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<WaterBloc>().add(const LoadWaterToday()),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WaterLoaded state, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // ── Circular Wave Tracker Widget ──────────────────────────────────
          _buildWaveProgressRing(state, l10n),
          const SizedBox(height: 32),

          // ── Quick-Add Grid Options ────────────────────────────────────────
          _buildQuickAddGrid(context, state.quickAddOptions),
          const SizedBox(height: 24),

          // ── Custom Logging Button ─────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => _showCustomLogDialog(context, l10n),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.waterAddCustom),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
          const SizedBox(height: 32),

          // ── Logs list history ─────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.homeRecentMeals.replaceFirst(l10n.homeRecentMeals.split(' ')[0], l10n.waterToday),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          _buildLogsList(context, state.logs, l10n),
        ],
      ),
    );
  }

  Widget _buildWaveProgressRing(WaterLoaded state, AppLocalizations l10n) {
    final double radius = 100.0;
    final isComplete = state.totalMl >= state.goalMl;

    return Center(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 4),
          color: AppColors.surface,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wave overlay mimicking water level
            ClipOval(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  height: radius * 2 * (state.progressPct / 100).clamp(0.0, 1.0),
                  color: AppColors.protein.withOpacity(0.18),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isComplete ? Icons.star_rounded : Icons.water_drop_rounded,
                  size: 40,
                  color: AppColors.protein,
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.totalMl} ${l10n.unitMl}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  isComplete ? l10n.waterGoalReached : l10n.waterRemainingMl(state.remainingMl),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                    color: isComplete ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddGrid(BuildContext context, List<int> options) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final amount = options[index];
        IconData cupIcon = Icons.local_drink_rounded;
        if (amount >= 1000) cupIcon = Icons.wine_bar_rounded; // bottle represent

        return ElevatedButton.icon(
          onPressed: () {
            context.read<WaterBloc>().add(LogWaterIntake(amount));
          },
          icon: Icon(cupIcon, size: 16),
          label: Text('$amount'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.protein,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsList(BuildContext context, List<dynamic> logs, AppLocalizations l10n) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(l10n.noDataYet, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final String id = log['id'];
        final int amount = log['amountMl'];
        final String time = _formatTime(log['loggedAt']);

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: AppColors.error,
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (dir) => _confirmDeleteDialog(context, l10n),
          onDismissed: (dir) {
            context.read<WaterBloc>().add(DeleteWaterLogEvent(id));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              color: AppColors.surface,
            ),
            child: ListTile(
              leading: const Icon(Icons.water_drop_rounded, color: AppColors.protein),
              title: Text('$amount ${l10n.unitMl}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              subtitle: Text(time, style: const TextStyle(color: AppColors.textSecondary)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                onPressed: () async {
                  final bloc = context.read<WaterBloc>();
                  final confirm = await _confirmDeleteDialog(context, l10n);
                  if (confirm == true) {
                    bloc.add(DeleteWaterLogEvent(id));
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final minute = date.minute.toString().padLeft(2, '0');
      final hour = date.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $ampm';
    } catch (e) {
      return '';
    }
  }

  Future<bool?> _confirmDeleteDialog(BuildContext context, AppLocalizations l10n) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l10n.deleteButton),
          content: Text(l10n.waterDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l10n.deleteButton),
            ),
          ],
        );
      },
    );
  }

  void _showCustomLogDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l10n.waterAddCustom),
          content: TextFormField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'ml'),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _customAmountController.clear();
                Navigator.pop(ctx);
              },
              child: Text(l10n.cancelButton),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = int.tryParse(_customAmountController.text.trim());
                if (amount != null && amount > 0) {
                  context.read<WaterBloc>().add(LogWaterIntake(amount));
                }
                _customAmountController.clear();
                Navigator.pop(ctx);
              },
              child: Text(l10n.addButton),
            ),
          ],
        );
      },
    );
  }
}
