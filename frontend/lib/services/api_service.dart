import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

// All API calls to Flask backend — change baseUrl for physical device
class ApiService {
  // Android emulator uses 10.0.2.2, physical device uses LAN IP
  static const String baseUrl = 'http://10.0.2.2:5000';

  // POST /api/scan — base64 image → ingredient list
  static Future<List<String>> scanImage(String base64Image) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return List<String>.from(data['data']['ingredients']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/recipes — ingredient list → recipe list
  static Future<List<Recipe>> getRecipes(List<String> ingredients) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ingredients': ingredients}),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return (data['data'] as List).map((r) => Recipe.fromJson(r)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // GET /api/recipe/:id — single recipe detail
  static Future<Recipe?> getRecipeDetail(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recipe/$id'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return Recipe.fromJson(data['data']);
      return null;
    } catch (_) {
      return null;
    }
  }

  // POST /api/chat — message → AI reply
  static Future<String> sendChat(String message) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data']['reply'] as String;
      return 'Sorry, I could not get a response. Try again!';
    } catch (_) {
      return 'Connection error. Is the backend running?';
    }
  }

  // POST /api/goals — weight/height/age/goal → TDEE + targets
  static Future<Map<String, dynamic>?> setGoals({
    required double weight, required double height,
    required int age, required String goal, required String sex,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/goals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'weight': weight, 'height': height, 'age': age, 'goal': goal, 'sex': sex}),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data'] as Map<String, dynamic>;
      return null;
    } catch (_) {
      return null;
    }
  }

  // GET /api/favorites — returns saved recipes for user
  static Future<List<Recipe>> getFavorites({String userId = 'default'}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/favorites?user_id=$userId'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return (data['data'] as List).map((r) => Recipe.fromJson(r)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/favorites — save a recipe as favorite
  static Future<void> addFavorite(int recipeId, {String userId = 'default'}) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/favorites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'recipe_id': recipeId}),
      );
    } catch (_) {}
  }

  // GET /api/favorites/check/<id> — is recipe saved?
  static Future<bool> isFavorite(int recipeId, {String userId = 'default'}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/favorites/check/$recipeId?user_id=$userId'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data']['is_favorite'] as bool;
      return false;
    } catch (_) {
      return false;
    }
  }

  // POST or DELETE /api/favorites — toggle favorite state, returns new state
  static Future<bool> toggleFavorite(int recipeId, {String userId = 'default'}) async {
    final currently = await isFavorite(recipeId, userId: userId);
    try {
      if (currently) {
        await http.delete(Uri.parse('$baseUrl/api/favorites/$recipeId?user_id=$userId'));
        return false;
      } else {
        await http.post(
          Uri.parse('$baseUrl/api/favorites'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'recipe_id': recipeId}),
        );
        return true;
      }
    } catch (_) {
      return currently;
    }
  }

  // GET /api/history — returns cooking history for user
  static Future<List<Map<String, dynamic>>> getHistory({String userId = 'default'}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/history?user_id=$userId'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // GET /api/history/stats — aggregated stats
  static Future<Map<String, int>> getHistoryStats({String userId = 'default'}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/history/stats?user_id=$userId'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        final d = data['data'] as Map<String, dynamic>;
        return {
          'total_sessions':     d['total_sessions']     as int? ?? 0,
          'total_recipes':      d['total_recipes']      as int? ?? 0,
          'sessions_this_week': d['sessions_this_week'] as int? ?? 0,
        };
      }
      return {};
    } catch (_) {
      return {};
    }
  }
  static Future<void> deleteHistory(int id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/history/$id'));
    } catch (_) {}
  }

  static Future<void> clearHistory({String userId = 'default'}) async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/history?user_id=$userId'));
    } catch (_) {}
  }

  static Future<void> logHistory({
    required String ingredientNames,
    String userId = 'default',
    String actionType = 'cooked',
    int recipeCount = 1,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'action_type': actionType,
          'ingredient_names': ingredientNames,
          'recipe_count': recipeCount,
        }),
      );
    } catch (_) {}
  }
}
