import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/recipe.dart' show Recipe, RecipeIngredient;

/// Persists browse-mode recipes to a local SQLite DB so users can
/// browse all recipes with zero internet connection.
///
/// Only used for the browse catalogue (empty ingredients).
/// AI-generated recipes (custom ingredients) are not cached — they are
/// personalised and require a live connection by design.
class OfflineRecipeService {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dbPath = p.join(await getDatabasesPath(), 'plately_offline.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_recipes (
            id          INTEGER PRIMARY KEY,
            name        TEXT    NOT NULL,
            cook_time   TEXT    NOT NULL,
            difficulty  TEXT    NOT NULL,
            instructions TEXT  NOT NULL,
            tags        TEXT    NOT NULL,
            image_url   TEXT    NOT NULL,
            calories    INTEGER NOT NULL DEFAULT 0,
            protein     INTEGER NOT NULL DEFAULT 0,
            carbs       INTEGER NOT NULL DEFAULT 0,
            fat         INTEGER NOT NULL DEFAULT 0,
            ingredients TEXT    NOT NULL DEFAULT '[]'
          )
        ''');
      },
    );
    return _db!;
  }

  /// Cache a full list of recipes — INSERT OR REPLACE so we always have
  /// the latest server data locally.
  static Future<void> cacheRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) return;
    final db = await _open();
    final batch = db.batch();
    for (final r in recipes) {
      batch.insert(
        'cached_recipes',
        {
          'id':           r.id,
          'name':         r.name,
          'cook_time':    r.cookTime,
          'difficulty':   r.difficulty,
          'instructions': r.instructions,
          'tags':         r.tags,
          'image_url':    r.imageUrl,
          'calories':     r.calories,
          'protein':      r.protein,
          'carbs':        r.carbs,
          'fat':          r.fat,
          'ingredients':  jsonEncode(r.ingredients.map((i) => {
                            'name': i.name,
                            'amount': i.amount,
                          }).toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Return all cached recipes, newest cache entries first.
  static Future<List<Recipe>> getCachedRecipes() async {
    final db = await _open();
    final rows = await db.query('cached_recipes', orderBy: 'id ASC');
    return rows.map(_rowToRecipe).toList();
  }

  /// Return cached recipes filtered by tag (case-insensitive LIKE).
  static Future<List<Recipe>> getCachedRecipesByTag(String tag) async {
    final db = await _open();
    final rows = await db.query(
      'cached_recipes',
      where: 'tags LIKE ?',
      whereArgs: ['%$tag%'],
      orderBy: 'id ASC',
    );
    return rows.map(_rowToRecipe).toList();
  }

  /// True if there is at least one cached recipe.
  static Future<bool> hasCache() async {
    final db = await _open();
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cached_recipes'),
    );
    return (count ?? 0) > 0;
  }

  static Future<void> clearCache() async {
    final db = await _open();
    await db.delete('cached_recipes');
  }

  // ── Row → Recipe ──────────────────────────────────────────────────────────
  static Recipe _rowToRecipe(Map<String, dynamic> row) {
    List<RecipeIngredient> ingredients = [];
    try {
      final raw = row['ingredients'] as String? ?? '[]';
      final list = jsonDecode(raw) as List<dynamic>;
      ingredients = list.map((m) => RecipeIngredient(
        name:   (m as Map<String, dynamic>)['name'] as String? ?? '',
        amount: m['amount'] as String? ?? '',
      )).toList();
    } catch (_) {}

    return Recipe(
      id:           row['id'] as int,
      name:         row['name'] as String,
      cookTime:     row['cook_time'] as String,
      difficulty:   row['difficulty'] as String,
      instructions: row['instructions'] as String,
      tags:         row['tags'] as String,
      imageUrl:     row['image_url'] as String,
      calories:     row['calories'] as int,
      protein:      row['protein'] as int,
      carbs:        row['carbs'] as int,
      fat:          row['fat'] as int,
      ingredients:  ingredients,
    );
  }
}
