// lib/features/auth/data/models/auth_models.dart
// Calc-Calories — User, AuthRequest, and AuthResponse Data Models

class User {
  final String id;
  final String name;
  final String email;
  final bool isPremium;
  final int dailyCalorieGoal;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.isPremium,
    required this.dailyCalorieGoal,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Standardizing backend response structure: user profile details can be nested under goals or flat
    final goals = json['goals'] as Map<String, dynamic>?;
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isPremium: json['isPremium'] as bool? ?? false,
      dailyCalorieGoal: goals != null
          ? (goals['dailyCalories'] as num? ?? 2000).toInt()
          : (json['dailyCalorieGoal'] as num? ?? 2000).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isPremium': isPremium,
        'dailyCalorieGoal': dailyCalorieGoal,
      };
}

class AuthRequest {
  final String? name;
  final String email;
  final String password;

  const AuthRequest({
    this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'email': email,
      'password': password,
    };
    if (name != null) {
      data['name'] = name;
    }
    return data;
  }
}

class AuthResponse {
  final String token;
  final User user;

  const AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      user: User.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': user.toJson(),
      };
}
