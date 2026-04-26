// Mifflin-St Jeor TDEE calculator + protein targets
// Used in Profile screen and /api/goals backend

class NutritionCalc {
  // Calculate Base Metabolic Rate
  // sex: 'male' or 'female', weight in kg, height in cm, age in years
  static double bmr({
    required String sex,
    required double weight,
    required double height,
    required int age,
  }) {
    final base = (10 * weight) + (6.25 * height) - (5 * age);
    return sex == 'male' ? base + 5 : base - 161;
  }

  // Calculate Total Daily Energy Expenditure
  // activity: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active'
  static double tdee({required double bmr, required String activity}) {
    const factors = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very_active': 1.9,
    };
    return bmr * (factors[activity] ?? 1.55);
  }

  // Daily protein target in grams
  // goal: 'gain' | 'maintain' | 'lose'
  static double proteinTarget({required double weight, required String goal}) {
    const rates = {'gain': 2.0, 'maintain': 1.6, 'lose': 1.2};
    return weight * (rates[goal] ?? 1.6);
  }

  // Calorie target adjusted for goal
  static double calorieTarget({required double tdee, required String goal}) {
    if (goal == 'gain') return tdee + 300;
    if (goal == 'lose') return tdee - 500;
    return tdee;
  }
}
