// lib/core/theme/app_colors.dart
// Calc-Calories — Color Palette

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Brand (Teal-blue accents) ────────────────
  static const Color primary = Color(0xFF00B4D8);       // Teal-blue
  static const Color primaryDark = Color(0xFF0077B6);
  static const Color primaryLight = Color(0xFF90E0EF);
  static const Color primarySurface = Color(0xFF023E8A); 

  // ── Background (Deep velvety charcoal grey) ────────────
  static const Color background = Color(0xFF1E1E24);     // Deep charcoal
  static const Color surface = Color(0xFF2B2D31);        // Card background
  static const Color surfaceVariant = Color(0xFF383A40); // Elevated surface
  static const Color border = Color(0xFF404249);

  // ── Accent ────────────────────────────────────────────
  static const Color accent = Color(0xFF00B4D8);         // Teal-blue accent
  static const Color accentLight = Color(0xFF48CAE4);

  // ── Macros Colors ─────────────────────────────────────
  static const Color calories = Color(0xFF00B4D8);       // Teal for calories
  static const Color protein = Color(0xFF58A6FF);        // Blue
  static const Color carbs = Color(0xFFE9C46A);          // Soft gold
  static const Color fats = Color(0xFFE76F51);           // Muted crimson

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8F9FA);    // Very light cream/off-white
  static const Color textSecondary = Color(0xFFAEB4B7);
  static const Color textMuted = Color(0xFF6C757D);

  // ── Status ────────────────────────────────────────────
  static const Color success = Color(0xFF2A9D8F);
  static const Color warning = Color(0xFFE9C46A);
  static const Color error = Color(0xFFE76F51);
  static const Color info = Color(0xFF48CAE4);

  // ── Gradients ─────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)], // Flowing teal gradient
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E1E24), Color(0xFF2B2D31)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2B2D31), Color(0xFF383A40)],
  );
}
