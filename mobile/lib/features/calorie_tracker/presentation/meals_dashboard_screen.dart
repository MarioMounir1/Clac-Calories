// lib/features/calorie_tracker/presentation/meals_dashboard_screen.dart
// Calc-Calories — Meals Dashboard (Smart Scanner Rebuild)
//
// Architecture: StatefulWidget with 3 LayoutStates
//   - LayoutState.idle       → Clean slate with Snap/Upload action cards
//   - LayoutState.processing → Shimmer + pulsing analysis text
//   - LayoutState.resultLoaded → Analysis Result Card + contextual banner
//
// Networking: LocalLlamaService (Dio multipart/form-data)
// Data Model: LlamaMealResponse (fully typed)
// Manual Logging: ManualMealService (Dio JSON POST to /meals/manual)

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../domain/entities/meal_log_entity.dart';
import '../data/models/llama_meal_response.dart';
import '../data/services/local_llama_service.dart';
import '../../../../core/utils/constants.dart';

// ── Layout State Enum ─────────────────────────────────────────

enum LayoutState { idle, processing, resultLoaded }

// ── Theme Constants ───────────────────────────────────────────

class DashboardThemeColors {
  DashboardThemeColors._();

  static const Color background     = Color(0xFF030712);
  static const Color cardBackground = Color(0xFF0D1117);
  static const Color cardSurface    = Color(0xFF111827);
  static const Color accentEmerald  = Color(0xFF10B981);
  static const Color accentLime     = Color(0xFFA3E635);
  static const Color accentBlue     = Color(0xFF60A5FA);
  static const Color accentRed      = Color(0xFFF87171);
  static const Color accentAmber    = Color(0xFFFBBF24);
  static const Color textPrimary    = Color(0xFFF9FAFB);
  static const Color textSecondary  = Color(0xFF9CA3AF);
  static const Color textMuted      = Color(0xFF6B7280);
  static const Color trackBg        = Color(0xFF1F2937);
}

// ── Existing MealWarning / MealEntry models (preserved) ───────

class MealWarning {
  final String warningText;
  final bool isSevere;
  const MealWarning({required this.warningText, required this.isSevere});
  factory MealWarning.fromJson(Map<String, dynamic> json) => MealWarning(
        warningText: json['warningText'] as String? ?? '',
        isSevere: json['isSevere'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {'warningText': warningText, 'isSevere': isSevere};
}

class MealEntry {
  final String id;
  final String foodName;
  final String restaurantName;
  final double protein;
  final double carbs;
  final double fat;
  final double calories;
  final List<MealWarning> warnings;
  final bool isHighlyNutritious;
  final DateTime createdAt;
  final String source;
  final List<IngredientBreakdown> ingredientsBreakdown;

  const MealEntry({
    required this.id,
    required this.foodName,
    required this.restaurantName,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.warnings,
    required this.isHighlyNutritious,
    required this.createdAt,
    required this.source,
    required this.ingredientsBreakdown,
  });

  factory MealEntry.fromLlamaResponse(LlamaMealResponse r) {
    final a = r.mealAnalysis;
    final List<MealWarning> warnings = [];
    if (a.carbs > 70 && a.protein < 30) {
      warnings.add(const MealWarning(warningText: 'High carb / low protein ratio', isSevere: false));
    }
    if (a.calories > 800) {
      warnings.add(const MealWarning(warningText: 'High calorie meal detected', isSevere: true));
    }
    if (a.fats > 30) {
      warnings.add(const MealWarning(warningText: 'Elevated fat content', isSevere: false));
    }
    return MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodName: a.detectedFood,
      restaurantName: 'Smart Scanner',
      protein: a.protein.toDouble(),
      carbs: a.carbs.toDouble(),
      fat: a.fats.toDouble(),
      calories: a.calories.toDouble(),
      warnings: warnings,
      isHighlyNutritious: a.isNutritious,
      createdAt: DateTime.now(),
      source: 'image',
      ingredientsBreakdown: const [],
    );
  }
}

// ── Main Dashboard Widget ─────────────────────────────────────

class MealsDashboard extends StatefulWidget {
  final Map<String, dynamic>? foodSummary;
  final List<MealLogEntity>? mealLogs;

  const MealsDashboard({super.key, this.foodSummary, this.mealLogs});

  @override
  State<MealsDashboard> createState() => _MealsDashboardState();
}

class _MealsDashboardState extends State<MealsDashboard>
    with SingleTickerProviderStateMixin {
  // ── Macro totals ─────────────────────────────────────────
  late double caloriesConsumed;
  late double caloriesTarget;
  late double proteinConsumed;
  late double proteinTarget;
  late double carbsConsumed;
  late double carbsTarget;
  late double fatsConsumed;
  late double fatsTarget;

  // ── Feed ─────────────────────────────────────────────────
  late List<MealEntry> logs;

  // ── Scanner State machine ─────────────────────────────────
  LayoutState _layoutState = LayoutState.idle;
  LlamaMealResponse? _llamaResult;
  // ignore: unused_field
  String? _errorMessage;
  File? _selectedImage;

  // ── Services ─────────────────────────────────────────────
  final _llamaService   = LocalLlamaService();
  final _imagePicker    = ImagePicker();
  final _manualService  = ManualMealService();

  // ── Shimmer animation ─────────────────────────────────────
  late final AnimationController _shimmerController;
  late final Animation<double>   _shimmerAnim;

  // ── Pulse animation for processing text ───────────────────
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _initData();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Data initialization (preserved from original) ─────────

  void _initData() {
    if (widget.mealLogs != null && widget.mealLogs!.isNotEmpty) {
      logs = widget.mealLogs!.map((entity) {
        final isNutritious = entity.protein > 25 && entity.calories < 400;
        final List<MealWarning> warnings = [];
        if (entity.carbs > 80)     warnings.add(const MealWarning(warningText: 'High carb load detected', isSevere: false));
        if (entity.fats > 20)      warnings.add(const MealWarning(warningText: 'High saturated fat warning', isSevere: false));
        if (entity.calories > 700) warnings.add(const MealWarning(warningText: 'Sodium & saturated fat spike detected', isSevere: true));
        return MealEntry(
          id: entity.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          foodName: entity.mealName,
          restaurantName: entity.restaurantName,
          protein: entity.protein,
          carbs: entity.carbs,
          fat: entity.fats,
          calories: entity.calories,
          warnings: warnings,
          isHighlyNutritious: isNutritious,
          createdAt: entity.createdAt,
          source: entity.source,
          ingredientsBreakdown: entity.ingredientsBreakdown,
        );
      }).toList();
    } else {
      logs = [];
    }
    _recalcTotals();
  }

  void _recalcTotals() {
    final goals = widget.foodSummary?['goals'] as Map<String, dynamic>? ?? {};
    caloriesTarget = (goals['calories'] as num?)?.toDouble() ?? 2400.0;
    proteinTarget  = (goals['protein']  as num?)?.toDouble() ?? 170.0;
    carbsTarget    = (goals['carbs']    as num?)?.toDouble() ?? 250.0;
    fatsTarget     = (goals['fats']     as num?)?.toDouble() ?? 80.0;

    caloriesConsumed = logs.fold(0.0, (s, m) => s + m.calories);
    proteinConsumed  = logs.fold(0.0, (s, m) => s + m.protein);
    carbsConsumed    = logs.fold(0.0, (s, m) => s + m.carbs);
    fatsConsumed     = logs.fold(0.0, (s, m) => s + m.fat);
  }

  // ── Image Pick & Upload ───────────────────────────────────

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _layoutState   = LayoutState.processing;
      _llamaResult   = null;
      _errorMessage  = null;
    });

    try {
      final result = await _llamaService.scanMealImage(_selectedImage!);

      if (!mounted) return;
      setState(() {
        _llamaResult = result;
        _layoutState = LayoutState.resultLoaded;
      });
    } on LlamaApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _layoutState  = LayoutState.idle;
      });
      _showErrorSnackbar(e.message);
    } on LlamaNetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _layoutState  = LayoutState.idle;
      });
      _showErrorSnackbar(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _layoutState  = LayoutState.idle;
      });
      _showErrorSnackbar('Unexpected error: $e');
    }
  }

  void _logResultToFeed() {
    if (_llamaResult == null) return;
    final entry = MealEntry.fromLlamaResponse(_llamaResult!);
    setState(() {
      logs.insert(0, entry);
      _recalcTotals();
      _layoutState  = LayoutState.idle;
      _llamaResult  = null;
      _selectedImage = null;
    });
  }

  void _discardResult() {
    setState(() {
      _layoutState   = LayoutState.idle;
      _llamaResult   = null;
      _selectedImage = null;
    });
  }

  // ── Manual Macro Log Bottom Sheet ────────────────────────

  void _showManualLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualLogSheet(
        onSaved: (entry) {
          setState(() {
            logs.insert(0, entry);
            _recalcTotals();
          });
        },
        service: _manualService,
        onError: _showErrorSnackbar,
      ),
    );
  }

  void _showErrorSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: DashboardThemeColors.accentRed, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: DashboardThemeColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: DashboardThemeColors.background,
        colorScheme: const ColorScheme.dark(
          primary: DashboardThemeColors.accentEmerald,
          secondary: DashboardThemeColors.accentLime,
          surface: DashboardThemeColors.cardBackground,
        ),
      ),
      child: Scaffold(
        backgroundColor: DashboardThemeColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildMacroRings(),
                const SizedBox(height: 28),

                // ── AI Canvas area (state-driven) ──────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildAiCanvas(),
                ),

                const SizedBox(height: 28),
                _buildFeedSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() {
    final todayStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DashboardThemeColors.accentEmerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LOCAL PROCESSING • ONLINE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: DashboardThemeColors.accentEmerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Meals Dashboard',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: DashboardThemeColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              todayStr,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: DashboardThemeColors.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: DashboardThemeColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DashboardThemeColors.trackBg),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: DashboardThemeColors.accentEmerald,
            size: 24,
          ),
        ),
      ],
    );
  }

  // ── MACRO RINGS ───────────────────────────────────────────

  Widget _buildMacroRings() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: _showManualLogSheet,
        borderRadius: BorderRadius.circular(24),
        splashColor: DashboardThemeColors.accentEmerald.withValues(alpha: 0.06),
        highlightColor: DashboardThemeColors.accentEmerald.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DashboardThemeColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DashboardThemeColors.trackBg),
            boxShadow: [
              BoxShadow(
                color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.04),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Daily Performance',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: DashboardThemeColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Tooltip(
                        message: 'Tap to log manually',
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: DashboardThemeColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${caloriesTarget > 0 ? ((caloriesConsumed / caloriesTarget) * 100).round() : 0}% Target',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: DashboardThemeColors.accentEmerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                const spacing = 12.0;
                final itemW = (constraints.maxWidth - spacing * 3) / 4;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRing('CALORIES', caloriesConsumed, caloriesTarget, 'kcal', DashboardThemeColors.accentLime,   itemW),
                    _buildRing('PROTEIN',  proteinConsumed,  proteinTarget,  'g',    DashboardThemeColors.accentEmerald, itemW),
                    _buildRing('CARBS',    carbsConsumed,    carbsTarget,    'g',    DashboardThemeColors.accentBlue,    itemW),
                    _buildRing('FATS',     fatsConsumed,     fatsTarget,     'g',    DashboardThemeColors.accentRed,     itemW),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRing(String label, double consumed, double target, String unit,
      Color color, double width) {
    final pct = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: pct),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => CustomPaint(
              size: Size(width - 4, width - 4),
              painter: CustomCircularProgressPainter(
                progress: v,
                color: color,
                trackColor: DashboardThemeColors.trackBg,
                strokeWidth: 6.5,
              ),
              child: SizedBox(
                width: width - 4,
                height: width - 4,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${consumed.round()}',
                        style: GoogleFonts.outfit(
                          fontSize: width > 75 ? 15 : 13,
                          fontWeight: FontWeight.w800,
                          color: DashboardThemeColors.textPrimary,
                        ),
                      ),
                      Text(
                        unit,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: DashboardThemeColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: DashboardThemeColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'Goal: ${target.round()}',
            style: GoogleFonts.inter(
              fontSize: 8,
              color: DashboardThemeColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── AI CANVAS (STATE SWITCH) ───────────────────────────────

  Widget _buildAiCanvas() {
    switch (_layoutState) {
      case LayoutState.processing:
        return _buildProcessingState();
      case LayoutState.resultLoaded:
        return _buildResultCard();
      case LayoutState.idle:
        return _buildIdleState();
    }
  }

  // ── STATE 1: IDLE — Two action cards ─────────────────────

  Widget _buildIdleState() {
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt, color: DashboardThemeColors.accentLime, size: 18),
            const SizedBox(width: 6),
            Text(
              'SMART MEAL SCANNER',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: DashboardThemeColors.accentLime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Analyze your meal instantly using local offline models — 100% private, zero cloud.',
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: DashboardThemeColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.camera_alt_outlined,
                label: 'Snap Meal',
                subtitle: 'Use Camera',
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                accentColor: DashboardThemeColors.accentEmerald,
                onTap: () => _pickAndAnalyze(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                icon: Icons.image_outlined,
                label: 'Upload Screenshot',
                subtitle: 'From Gallery',
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                accentColor: DashboardThemeColors.accentBlue,
                onTap: () => _pickAndAnalyze(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Local AI badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DashboardThemeColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DashboardThemeColors.trackBg),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: DashboardThemeColors.accentEmerald,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '100% Local • No Cloud Required',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: DashboardThemeColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Powered by secure offline privacy engines — your data never leaves your device.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: DashboardThemeColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required LinearGradient gradient,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 150,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: DashboardThemeColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: accentColor.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STATE 2: PROCESSING — Shimmer + Pulse ─────────────────

  Widget _buildProcessingState() {
    return Column(
      key: const ValueKey('processing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview of selected image (small thumbnail)
        if (_selectedImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 16),

        // Shimmer loading card
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (_, __) {
            return Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        Color(0xFF111827),
                        Color(0xFF1F2937),
                        Color(0xFF10B981),
                        Color(0xFF1F2937),
                        Color(0xFF111827),
                      ],
                      stops: [
                        0.0,
                        (_shimmerAnim.value + 1.5) / 3.0 - 0.3,
                        (_shimmerAnim.value + 1.5) / 3.0,
                        (_shimmerAnim.value + 1.5) / 3.0 + 0.3,
                        1.0,
                      ].map((s) => s.clamp(0.0, 1.0)).toList(),
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcATop,
                  child: Container(
                    color: DashboardThemeColors.cardBackground,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shimmer placeholder lines
                        _shimmerLine(width: 0.5, height: 12),
                        const SizedBox(height: 12),
                        _shimmerLine(width: 0.8, height: 20),
                        const SizedBox(height: 10),
                        _shimmerLine(width: 0.65, height: 14),
                        const SizedBox(height: 20),
                        Row(children: [
                          _shimmerBox(60, 60),
                          const SizedBox(width: 12),
                          _shimmerBox(60, 60),
                          const SizedBox(width: 12),
                          _shimmerBox(60, 60),
                          const SizedBox(width: 12),
                          _shimmerBox(60, 60),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Pulse text label
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Opacity(
            opacity: _pulseAnim.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: DashboardThemeColors.accentEmerald,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Analyzing meal components locally...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DashboardThemeColors.accentEmerald,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerLine({required double width, required double height}) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: DashboardThemeColors.trackBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: DashboardThemeColors.trackBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // ── STATE 3: RESULT — Llama Analysis Card ─────────────────

  Widget _buildResultCard() {
    final result = _llamaResult!;
    final analysis = result.mealAnalysis;
    final rec = result.llamaRecommendation;

    return Column(
      key: const ValueKey('result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected image preview
        if (_selectedImage != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  _selectedImage!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        DashboardThemeColors.background.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              // "Local AI Verified" badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 12, color: Colors.black),
                      const SizedBox(width: 4),
                      Text(
                        'Locally Verified',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),

        // ── Llama Analysis Card ──────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: DashboardThemeColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.06),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.psychology_outlined,
                        color: DashboardThemeColors.accentEmerald,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            analysis.detectedFood,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: DashboardThemeColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Scan Analysis Result',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: DashboardThemeColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: DashboardThemeColors.trackBg, height: 1),
              const SizedBox(height: 20),

              // ── 2×2 Macros Grid ──────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _buildMacroCell('🔥 Calories', '${analysis.calories}', 'kcal', DashboardThemeColors.accentLime),
                    _buildMacroCell('💪 Protein',  '${analysis.protein}',  'g',    DashboardThemeColors.accentEmerald),
                    _buildMacroCell('🌾 Carbs',    '${analysis.carbs}',    'g',    DashboardThemeColors.accentBlue),
                    _buildMacroCell('🫙 Fats',     '${analysis.fats}',     'g',    DashboardThemeColors.accentRed),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Contextual Llama Recommendation Banner ──
              if (rec.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: rec.triggerWarning
                          ? DashboardThemeColors.accentAmber.withValues(alpha: 0.08)
                          : DashboardThemeColors.accentEmerald.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: rec.triggerWarning
                            ? DashboardThemeColors.accentAmber.withValues(alpha: 0.3)
                            : DashboardThemeColors.accentEmerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          rec.triggerWarning
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          color: rec.triggerWarning
                              ? DashboardThemeColors.accentAmber
                              : DashboardThemeColors.accentEmerald,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rec.message,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.5,
                              color: rec.triggerWarning
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFF6EE7B7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Action Buttons ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _logResultToFeed,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Log Meal',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardThemeColors.accentEmerald,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _discardResult,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DashboardThemeColors.textSecondary,
                        side: const BorderSide(color: DashboardThemeColors.trackBg),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Discard',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCell(String emoji, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: GoogleFonts.inter(fontSize: 11, color: DashboardThemeColors.textMuted),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DashboardThemeColors.textPrimary,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: DashboardThemeColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FEED SECTION (preserved from original) ────────────────

  Widget _buildFeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(
                "Today's Feed",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DashboardThemeColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DashboardThemeColors.trackBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${logs.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DashboardThemeColors.textPrimary,
                  ),
                ),
              ),
            ]),
            TextButton.icon(
              onPressed: () => _pickAndAnalyze(ImageSource.gallery),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: DashboardThemeColors.accentLime),
              label: Text(
                'Snap',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DashboardThemeColors.accentLime,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: DashboardThemeColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DashboardThemeColors.trackBg),
            ),
            child: Column(
              children: [
                const Icon(Icons.restaurant_outlined,
                    color: DashboardThemeColors.textMuted, size: 36),
                const SizedBox(height: 10),
                Text(
                  'No meals logged yet today.',
                  style: GoogleFonts.inter(color: DashboardThemeColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Snap a meal above to get started.',
                  style: GoogleFonts.inter(color: DashboardThemeColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          Column(children: logs.map(_buildMealLogCard).toList()),
      ],
    );
  }

  Widget _buildMealLogCard(MealEntry meal) {
    final mealTime  = DateFormat('h:mm a').format(meal.createdAt.toLocal());
    final hasSevere = meal.warnings.any((w) => w.isSevere);
    final hasWarn   = meal.warnings.isNotEmpty;
    Color borderColor = DashboardThemeColors.trackBg;
    if (hasSevere) {
      borderColor = DashboardThemeColors.accentRed;
    } else if (hasWarn) {
      borderColor = DashboardThemeColors.accentAmber;
    } else if (meal.isHighlyNutritious) {
      borderColor = DashboardThemeColors.accentEmerald;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardThemeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: hasWarn || meal.isHighlyNutritious ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasWarn) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: (hasSevere ? DashboardThemeColors.accentRed : DashboardThemeColors.accentAmber).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (hasSevere ? DashboardThemeColors.accentRed : DashboardThemeColors.accentAmber).withValues(alpha: 0.25),
                ),
              ),
              child: Row(children: [
                Icon(
                  hasSevere ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                  color: hasSevere ? DashboardThemeColors.accentRed : DashboardThemeColors.accentAmber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meal.warnings.map((w) => w.warningText).join(', '),
                    style: GoogleFonts.inter(
                      color: hasSevere ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DashboardThemeColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  meal.source == 'image' ? Icons.camera_alt_outlined : Icons.restaurant_outlined,
                  color: meal.isHighlyNutritious ? DashboardThemeColors.accentEmerald
                      : (hasSevere ? DashboardThemeColors.accentRed : DashboardThemeColors.accentLime),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        meal.restaurantName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: DashboardThemeColors.accentEmerald,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (meal.isHighlyNutritious) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('🌿 NUTRITIOUS',
                              style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: DashboardThemeColors.accentEmerald)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(meal.foodName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: DashboardThemeColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(mealTime, style: GoogleFonts.inter(fontSize: 11, color: DashboardThemeColors.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: DashboardThemeColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DashboardThemeColors.trackBg),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${meal.calories.round()}',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: DashboardThemeColors.textPrimary)),
                  const SizedBox(width: 2),
                  Text('kcal', style: GoogleFonts.inter(fontSize: 9, color: DashboardThemeColors.textSecondary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildMacroLabel('Protein', '${meal.protein.round()}g', DashboardThemeColors.accentEmerald),
            _buildMacroLabel('Carbs',   '${meal.carbs.round()}g',   DashboardThemeColors.accentBlue),
            _buildMacroLabel('Fats',    '${meal.fat.round()}g',     DashboardThemeColors.accentRed),
          ]),
        ],
      ),
    );
  }

  Widget _buildMacroLabel(String label, String value, Color color) {
    return Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label: ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: DashboardThemeColors.textSecondary)),
      Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: DashboardThemeColors.textPrimary)),
    ]);
  }
}

// ── Manual Meal Service (Dio POST to /meals/manual) ───────────

class ManualMealService {
  static const Duration _timeout = Duration(seconds: 20);

  Future<void> postManualLog({
    required String mealName,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    // We reuse the same DIO setup from LocalLlamaService (shared base URL)
    // but with a simple JSON body — no auth required for local dev.
    // In production, add the same JWT interceptor as LocalLlamaService.
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiV1,
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    );

    await dio.post<dynamic>(
      '/meals/manual',
      data: {
        'mealName': mealName.isEmpty ? 'Manual Entry' : mealName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'loggedAt': DateTime.now().toIso8601String(),
      },
    );
  }
}

// ── Manual Log Bottom Sheet Widget ───────────────────────────

class _ManualLogSheet extends StatefulWidget {
  final void Function(MealEntry entry) onSaved;
  final ManualMealService service;
  final void Function(String) onError;

  const _ManualLogSheet({
    required this.onSaved,
    required this.service,
    required this.onError,
  });

  @override
  State<_ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends State<_ManualLogSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _mealNameCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl  = TextEditingController();
  final _carbsCtrl    = TextEditingController();
  final _fatsCtrl     = TextEditingController();
  bool _isSaving      = false;

  @override
  void dispose() {
    _mealNameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final calories = double.parse(_caloriesCtrl.text.trim());
    final protein  = double.parse(_proteinCtrl.text.trim());
    final carbs    = double.parse(_carbsCtrl.text.trim());
    final fats     = double.parse(_fatsCtrl.text.trim());
    final name     = _mealNameCtrl.text.trim();

    // Fire-and-forget POST — local state updates immediately
    // If the server call fails, we still update the UI (offline-first)
    widget.service.postManualLog(
      mealName: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    ).catchError((e) {
      widget.onError('Could not sync to server: $e');
    });

    final entry = MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodName: name.isEmpty ? 'Manual Entry' : name,
      restaurantName: 'Manual Log',
      protein: protein,
      carbs: carbs,
      fat: fats,
      calories: calories,
      warnings: const [],
      isHighlyNutritious: protein > 25 && calories < 400,
      createdAt: DateTime.now(),
      source: 'manual',
      ingredientsBreakdown: const [],
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved(entry);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: DashboardThemeColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sheet handle ─────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: DashboardThemeColors.trackBg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // ── Title ────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DashboardThemeColors.accentEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: DashboardThemeColors.accentEmerald,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Macro Log',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DashboardThemeColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Log a meal by entering macros directly',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: DashboardThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Meal name (optional) ─────────────────────
            _MacroField(
              controller: _mealNameCtrl,
              label: 'Meal Name',
              hint: 'e.g. Grilled Chicken & Rice',
              unit: '',
              icon: Icons.restaurant_menu_outlined,
              isOptional: true,
              validator: null,
            ),

            const SizedBox(height: 12),

            // ── Macro fields in 2×2 grid ─────────────────
            Row(
              children: [
                Expanded(
                  child: _MacroField(
                    controller: _caloriesCtrl,
                    label: 'Calories',
                    hint: '0',
                    unit: 'kcal',
                    icon: Icons.local_fire_department_outlined,
                    iconColor: DashboardThemeColors.accentLime,
                    validator: _numValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MacroField(
                    controller: _proteinCtrl,
                    label: 'Protein',
                    hint: '0',
                    unit: 'g',
                    icon: Icons.fitness_center_outlined,
                    iconColor: DashboardThemeColors.accentEmerald,
                    validator: _numValidator,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _MacroField(
                    controller: _carbsCtrl,
                    label: 'Carbs',
                    hint: '0',
                    unit: 'g',
                    icon: Icons.grain_outlined,
                    iconColor: DashboardThemeColors.accentBlue,
                    validator: _numValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MacroField(
                    controller: _fatsCtrl,
                    label: 'Fats',
                    hint: '0',
                    unit: 'g',
                    icon: Icons.opacity_outlined,
                    iconColor: DashboardThemeColors.accentRed,
                    validator: _numValidator,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Save button ──────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Log',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DashboardThemeColors.accentEmerald,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      DashboardThemeColors.accentEmerald.withValues(alpha: 0.5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _numValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final n = double.tryParse(value.trim());
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Must be ≥ 0';
    return null;
  }
}

// ── Reusable Macro Input Field ────────────────────────────────

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String unit;
  final IconData icon;
  final Color? iconColor;
  final bool isOptional;
  final String? Function(String?)? validator;

  const _MacroField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.unit,
    required this.icon,
    this.iconColor,
    this.isOptional = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: isOptional
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      validator: isOptional ? null : validator,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: DashboardThemeColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label + (isOptional ? ' (optional)' : ''),
        hintText: hint,
        suffixText: unit.isEmpty ? null : unit,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: iconColor ?? DashboardThemeColors.textMuted,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: DashboardThemeColors.textMuted,
        ),
        hintStyle: GoogleFonts.outfit(
          fontSize: 13,
          color: DashboardThemeColors.textMuted.withValues(alpha: 0.5),
        ),
        suffixStyle: GoogleFonts.inter(
          fontSize: 11,
          color: DashboardThemeColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: DashboardThemeColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashboardThemeColors.trackBg),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashboardThemeColors.trackBg),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: DashboardThemeColors.accentEmerald,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashboardThemeColors.accentRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: DashboardThemeColors.accentRed,
            width: 1.5,
          ),
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 10,
          color: DashboardThemeColors.accentRed,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

// ── Custom Circular Progress Painter (preserved) ──────────────

class CustomCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  CustomCircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2,
      2 * 3.1415926535 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomCircularProgressPainter old) =>
      old.progress != progress || old.color != color ||
      old.trackColor != trackColor || old.strokeWidth != strokeWidth;
}
