class RecipeIngredient {
  final String name;
  final String amount;
  const RecipeIngredient({required this.name, required this.amount});
  factory RecipeIngredient.fromJson(Map<String, dynamic> j) =>
      RecipeIngredient(name: j['name'] as String, amount: j['amount'] as String? ?? '');
}

class Recipe {
  final int id;
  final String name;
  final String cookTime;
  final String difficulty;
  final String instructions;
  final String tags;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id, required this.name, required this.cookTime,
    required this.difficulty, required this.instructions,
    this.tags = '',
    required this.calories, required this.protein,
    required this.carbs, required this.fat,
    this.ingredients = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> j) {
    final n = j['nutrition'] as Map<String, dynamic>?;
    final ingList = j['ingredients'] as List<dynamic>? ?? [];
    return Recipe(
      id:           j['id'] as int,
      name:         j['name'] as String,
      cookTime:     j['cook_time'] as String,
      difficulty:   j['difficulty'] as String,
      instructions: j['instructions'] as String,
      tags:         j['tags'] as String? ?? '',
      calories:     n?['calories'] as int? ?? j['calories'] as int? ?? 0,
      protein:      n?['protein']  as int? ?? j['protein']  as int? ?? 0,
      carbs:        n?['carbs']    as int? ?? j['carbs']    as int? ?? 0,
      fat:          n?['fat']      as int? ?? j['fat']      as int? ?? 0,
      ingredients:  ingList.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
