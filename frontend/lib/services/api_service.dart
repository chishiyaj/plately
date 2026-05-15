import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import '../services/user_prefs_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'PLATELY_API_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  static Future<http.Response?> _post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 20)}) async {
    try {
      return await http
          .post(Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(timeout);
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response?> _get(String path,
      {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      return await http.get(Uri.parse('$baseUrl$path')).timeout(timeout);
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response?> _delete(String path,
      {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      return await http.delete(Uri.parse('$baseUrl$path')).timeout(timeout);
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // -- SCAN ------------------------------------------------------------------
  static Future<ScanResult> scanImage(String base64Image) async {
    final res = await _post('/api/scan', {'image_base64': base64Image},
        timeout: const Duration(seconds: 40));
    if (res == null) return const ScanResult(ingredients: [], offline: true);
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return ScanResult(
          ingredients: List<String>.from(data['data']['ingredients'] ?? []),
          message: data['message'] as String?,
        );
      }
      return ScanResult(ingredients: [], message: data['message'] as String?);
    } catch (_) {
      return const ScanResult(ingredients: []);
    }
  }

  // -- RECIPES ---------------------------------------------------------------
  // Returns RecipesResult which carries both the list and an optional ai_note.
  // Throws RecipeApiException when backend status == error.
  static Future<RecipesResult> getRecipesResult(List<String> ingredients) async {
    // Always send prefs -- both browse mode and ingredient mode need them.
    // Browse mode uses prefs to filter Vegetarian + sort High-Protein.
    // Ingredient mode uses prefs for AI recipe generation constraints.
    final p = await UserPrefsService.load();
    final prefs = <String, dynamic>{
      'goal':         p['goal']         ?? 'maintain',
      'cal_goal':     p['cal_goal']     ?? 2200,
      'protein_goal': p['protein_goal'] ?? 120,
      'pref_veg':     p['pref_veg']     ?? false,
      'pref_gluten':  p['pref_gluten']  ?? false,
      'pref_dairy':   p['pref_dairy']   ?? false,
      'pref_hipro':   p['pref_hipro']   ?? true,
    };

    final res = await _post('/api/recipes', {
      'ingredients': ingredients,
      'prefs': prefs,
    }, timeout: const Duration(seconds: 40));

    if (res == null) {
      return const RecipesResult(recipes: [], offline: true);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (data['status'] == 'error') {
      final msg = data['message'] as String? ?? 'No recipes found';
      throw RecipeApiException(msg);
    }

    final list = (data['data'] as List)
        .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
        .toList();

    final meta = data['meta'] as Map<String, dynamic>?;
    final aiNote = meta?['ai_note'] as String?;
    return RecipesResult(recipes: list, aiNote: aiNote);
  }

  // Legacy wrapper -- returns plain list (offline fallback callers)
  static Future<List<Recipe>> getRecipes(List<String> ingredients) async {
    try {
      final result = await getRecipesResult(ingredients);
      return result.recipes;
    } on RecipeApiException {
      return [];
    }
  }

  // -- RECIPE DETAIL ---------------------------------------------------------
  static Future<Recipe?> getRecipeDetail(int id) async {
    final res = await _get('/api/recipe/$id');
    if (res == null) return null;
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return Recipe.fromJson(data['data']);
      return null;
    } catch (_) {
      return null;
    }
  }

  // -- CHAT ------------------------------------------------------------------
  // Returns reply text. On error returns string prefixed 'ERROR:' for red bubble.
  static Future<String> sendChat(String message,
      {List<Map<String, String>>? history}) async {
    final res = await _post('/api/chat', {
      'message': message,
      'user_id': _uid,
      if (history != null && history.isNotEmpty) 'history': history,
    }, timeout: const Duration(seconds: 25));

    if (res == null) {
      return 'ERROR:No internet connection. Please check your network and try again.';
    }
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'ok') {
        return data['data']['reply'] as String;
      }
      final msg = data['message'] as String? ?? 'AI service error';
      return 'ERROR:$msg';
    } catch (_) {
      return 'ERROR:Something went wrong. Try again!';
    }
  }

  // -- GOALS -----------------------------------------------------------------
  static Future<Map<String, dynamic>?> setGoals({
    required double weight,
    required double height,
    required int age,
    required String goal,
    required String sex,
  }) async {
    final res = await _post('/api/goals', {
      'weight': weight, 'height': height,
      'age': age, 'goal': goal, 'sex': sex,
    });
    if (res == null) return null;
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data'] as Map<String, dynamic>;
      return null;
    } catch (_) {
      return null;
    }
  }

  // -- FAVORITES -------------------------------------------------------------
  static Future<List<Recipe>> getFavorites() async {
    final res = await _get('/api/favorites?user_id=$_uid');
    if (res == null) return [];
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return (data['data'] as List).map((r) => Recipe.fromJson(r)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> addFavorite(int recipeId) async {
    await _post('/api/favorites', {'user_id': _uid, 'recipe_id': recipeId});
  }

  static Future<bool> isFavorite(int recipeId) async {
    final res = await _get('/api/favorites/check/$recipeId?user_id=$_uid');
    if (res == null) return false;
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data']['is_favorite'] as bool;
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleFavorite(int recipeId) async {
    final currently = await isFavorite(recipeId);
    if (currently) {
      await _delete('/api/favorites/$recipeId?user_id=$_uid');
      return false;
    } else {
      await _post('/api/favorites', {'user_id': _uid, 'recipe_id': recipeId});
      return true;
    }
  }

  // -- HISTORY ---------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final res = await _get('/api/history?user_id=$_uid');
    if (res == null) return [];
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, int>> getHistoryStats() async {
    final res = await _get('/api/history/stats?user_id=$_uid');
    if (res == null) return {};
    try {
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        final d = data['data'] as Map<String, dynamic>;
        return {
          'total_sessions':       d['total_sessions']       as int? ?? 0,
          'total_recipes':        d['total_recipes']        as int? ?? 0,
          'distinct_recipe_count': d['distinct_recipe_count'] as int? ?? 0,
          'sessions_this_week':   d['sessions_this_week']   as int? ?? 0,
        };
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getDailyHistory(
      String userId, String date) async {
    final res = await _get(
        '/api/history/daily?user_id=${Uri.encodeComponent(userId)}&date=${Uri.encodeComponent(date)}');
    if (res == null) {
      return {'total_calories': 0, 'total_protein': 0, 'recipes': <String>[], 'meal_count': 0};
    }
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'ok') return data['data'] as Map<String, dynamic>;
    } catch (_) {}
    return {'total_calories': 0, 'total_protein': 0, 'recipes': <String>[], 'meal_count': 0};
  }

  static Future<bool> deleteHistory(int id) async {
    final res = await _delete('/api/history/$id?user_id=$_uid');
    if (res == null) return false;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearHistory() async {
    final res = await _delete('/api/history?user_id=$_uid');
    if (res == null) return false;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Wipes all server-side data for the current user (called on account deletion).
  static Future<void> deleteAllUserData() async {
    await Future.wait([
      _delete('/api/history?user_id=$_uid'),
      _delete('/api/favorites/all?user_id=$_uid'),
    ]);
  }

  static Future<void> logHistory({
    required String ingredientNames,
    String actionType = 'cooked',
    int recipeCount = 1,
    int caloriesLogged = 0,
    int proteinLogged = 0,
    int recipeId = 0,
    String recipeName = '',
  }) async {
    await _post('/api/history', {
      'user_id':          _uid,
      'action_type':      actionType,
      'ingredient_names': ingredientNames,
      'recipe_count':     recipeCount,
      'calories_logged':  caloriesLogged,
      'protein_logged':   proteinLogged,
      'recipe_id':        recipeId,
      'recipe_name':      recipeName,
    });
  }

  // -- KEEP-ALIVE PING -------------------------------------------------------
  static Future<void> ping() async {
    await _get('/api/health', timeout: const Duration(seconds: 10));
  }

  // -- ONLINE CHECK ----------------------------------------------------------
  /// Returns true if the backend is reachable. Times out after 3 seconds.
  static Future<bool> isOnline() async {
    final res = await _get('/api/health', timeout: const Duration(seconds: 3));
    if (res == null) return false;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}

// -- Value types --------------------------------------------------------------

class ScanResult {
  final List<String> ingredients;
  final String? message;
  final bool offline;
  const ScanResult({required this.ingredients, this.message, this.offline = false});
}

class RecipesResult {
  final List<Recipe> recipes;
  final String? aiNote; // e.g. "AI busy -- showing saved recipes instead"
  final bool offline;
  const RecipesResult({required this.recipes, this.aiNote, this.offline = false});
}

class RecipeApiException implements Exception {
  final String message;
  const RecipeApiException(this.message);
  @override
  String toString() => message;
}
