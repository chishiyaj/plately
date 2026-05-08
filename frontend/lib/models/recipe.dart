class RecipeIngredient {
  final String name;
  final String amount;
  const RecipeIngredient({required this.name, required this.amount});
  factory RecipeIngredient.fromJson(Map<String, dynamic> j) =>
      RecipeIngredient(name: j['name'] as String, amount: j['amount'] as String? ?? '');
  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

class Recipe {
  final int id;
  final String name;
  final String cookTime;
  final String difficulty;
  final String instructions;
  final String tags;
  final String imageUrl;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int costPhp;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id, required this.name, required this.cookTime,
    required this.difficulty, required this.instructions,
    this.tags = '',
    this.imageUrl = '',
    required this.calories, required this.protein,
    required this.carbs, required this.fat,
    this.costPhp = 0,
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
      imageUrl:     j['image_url'] as String? ?? '',
      calories:     n?['calories'] as int? ?? j['calories'] as int? ?? 0,
      protein:      n?['protein']  as int? ?? j['protein']  as int? ?? 0,
      carbs:        n?['carbs']    as int? ?? j['carbs']    as int? ?? 0,
      fat:          n?['fat']      as int? ?? j['fat']      as int? ?? 0,
      costPhp:      n?['cost_php'] as int? ?? j['cost_php'] as int? ?? 0,
      ingredients:  ingList.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cook_time': cookTime,
    'difficulty': difficulty,
    'instructions': instructions,
    'tags': tags,
    'image_url': imageUrl,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'cost_php': costPhp,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
  };

  Recipe copyWith({
    int? id, String? name, String? cookTime, String? difficulty,
    String? instructions, String? tags, String? imageUrl,
    int? calories, int? protein, int? carbs, int? fat, int? costPhp,
    List<RecipeIngredient>? ingredients,
  }) => Recipe(
    id:           id           ?? this.id,
    name:         name         ?? this.name,
    cookTime:     cookTime     ?? this.cookTime,
    difficulty:   difficulty   ?? this.difficulty,
    instructions: instructions ?? this.instructions,
    tags:         tags         ?? this.tags,
    imageUrl:     imageUrl     ?? this.imageUrl,
    calories:     calories     ?? this.calories,
    protein:      protein      ?? this.protein,
    carbs:        carbs        ?? this.carbs,
    fat:          fat          ?? this.fat,
    costPhp:      costPhp      ?? this.costPhp,
    ingredients:  ingredients  ?? this.ingredients,
  );
}
