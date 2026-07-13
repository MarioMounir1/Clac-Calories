// lib/features/calorie_tracker/data/models/llama_meal_response.dart
// Calc-Calories — Local Llama Meal Response Data Model
//
// Matches exactly the JSON payload from:
//   POST /api/v1/meals/scan-local
//
// Payload shape:
// {
//   "success": true,
//   "source": "local_llama_inference",
//   "mealAnalysis": {
//     "detectedFood": "Homemade Rice and Chicken Plate",
//     "calories": 620,
//     "protein": 42,
//     "carbs": 80,
//     "fats": 12
//   },
//   "llamaRecommendation": {
//     "triggerWarning": true,
//     "message": "..."
//   }
// }

// ── Nested: Meal Analysis ─────────────────────────────────────

class LlamaMealAnalysis {
  final String detectedFood;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;

  const LlamaMealAnalysis({
    required this.detectedFood,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  factory LlamaMealAnalysis.fromJson(Map<String, dynamic> json) {
    return LlamaMealAnalysis(
      detectedFood: json['detectedFood'] as String? ?? 'Unknown Meal',
      calories:     (json['calories']    as num?)?.toInt() ?? 0,
      protein:      (json['protein']     as num?)?.toInt() ?? 0,
      carbs:        (json['carbs']       as num?)?.toInt() ?? 0,
      fats:         (json['fats']        as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'detectedFood': detectedFood,
        'calories':     calories,
        'protein':      protein,
        'carbs':        carbs,
        'fats':         fats,
      };

  /// Total macro grams (useful for percentage calculations)
  int get totalMacroGrams => protein + carbs + fats;

  /// Quick nutritious check: high protein, moderate calories
  bool get isNutritious => protein >= 30 && calories < 600;
}

// ── Nested: Llama Recommendation ─────────────────────────────

class LlamaRecommendation {
  final bool triggerWarning;
  final String message;

  const LlamaRecommendation({
    required this.triggerWarning,
    required this.message,
  });

  factory LlamaRecommendation.fromJson(Map<String, dynamic> json) {
    return LlamaRecommendation(
      triggerWarning: json['triggerWarning'] as bool? ?? false,
      message:        json['message']        as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'triggerWarning': triggerWarning,
        'message':        message,
      };
}

// ── Root: Full Llama Meal Response ────────────────────────────

class LlamaMealResponse {
  final bool success;
  final String source;
  final LlamaMealAnalysis mealAnalysis;
  final LlamaRecommendation llamaRecommendation;

  const LlamaMealResponse({
    required this.success,
    required this.source,
    required this.mealAnalysis,
    required this.llamaRecommendation,
  });

  factory LlamaMealResponse.fromJson(Map<String, dynamic> json) {
    // Validate top-level structure
    if (json['success'] != true) {
      final errMsg = json['error'] as String? ?? 'Unknown error from local Llama API';
      throw LlamaApiException(errMsg, code: json['code'] as String?);
    }

    final analysisJson = json['mealAnalysis'];
    if (analysisJson == null || analysisJson is! Map<String, dynamic>) {
      throw const LlamaApiException(
        'Invalid response: missing or malformed "mealAnalysis" field.',
      );
    }

    final recJson = json['llamaRecommendation'];
    if (recJson == null || recJson is! Map<String, dynamic>) {
      throw const LlamaApiException(
        'Invalid response: missing or malformed "llamaRecommendation" field.',
      );
    }

    return LlamaMealResponse(
      success:             json['success'] as bool,
      source:              json['source']  as String? ?? 'local_llama_inference',
      mealAnalysis:        LlamaMealAnalysis.fromJson(analysisJson),
      llamaRecommendation: LlamaRecommendation.fromJson(recJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'success':             success,
        'source':              source,
        'mealAnalysis':        mealAnalysis.toJson(),
        'llamaRecommendation': llamaRecommendation.toJson(),
      };
}

// ── Custom Exception ──────────────────────────────────────────

class LlamaApiException implements Exception {
  final String message;
  final String? code;

  const LlamaApiException(this.message, {this.code});

  @override
  String toString() => code != null
      ? 'LlamaApiException [$code]: $message'
      : 'LlamaApiException: $message';
}
