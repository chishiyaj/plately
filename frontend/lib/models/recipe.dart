// Recipe model — maps to backend /api/recipe response
class Recipe {
  final int id;
  final String name;
  final String cookTime;
  final String difficulty;
  final String instructions;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;

  const Recipe({
    required this.id,
    required this.name,
    required this.cookTime,
    required this.difficulty,
    required this.instructions,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
  });

  // Parse from API JSON response
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as int,
      name: json['name'] as String,
      cookTime: json['cook_time'] as String,
      difficulty: json['difficulty'] as String,
      instructions: json['instructions'] as String,
      calories: json['calories'] as int? ?? 0,
      protein: json['protein'] as int? ?? 0,
      carbs: json['carbs'] as int? ?? 0,
      fat: json['fat'] as int? ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'cook_time': cookTime,
    'difficulty': difficulty, 'instructions': instructions,
    'calories': calories, 'protein': protein, 'carbs': carbs,
    'fat': fat, 'ingredients': ingredients,
  };
}
