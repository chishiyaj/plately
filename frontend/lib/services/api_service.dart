import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';

// All API calls to Flask backend â€” change baseUrl for physical device
class ApiService {
  // â”€â”€â”€ SWITCH THIS FOR DEMO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Emulator:       'http://10.0.2.2:5000'
  // Physical phone: 'http://192.168.100.15:5000'  â† use this for demo
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // ── SWITCH FOR DEPLOYMENT ──────────────────────────────────────────────────
  // Emulator:       'http://10.0.2.2:5000'
  // Physical phone: 'http://192.168.100.15:5000'
  // Production:     'https://YOUR-APP.up.railway.app'  <- paste Railway URL
  // ────────────────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://192.168.100.15:5000';

  /// Returns the current Firebase UID, or 'default' if not signed in.
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'default';

  // POST /api/scan â€” base64 image â†’ (ingredients, message)
  // message is non-null when AI falls back (timeout/parse error).
  static Future<({List<String> ingredients, String? message})> scanImage(String base64Image) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return (
          ingredients: List<String>.from(data['data']['ingredients']),
          message: data['message'] as String?,
        );
      }
      return (ingredients: <String>[], message: data['message'] as String? ?? 'Scan failed.');
    } catch (_) {
      return (ingredients: <String>[], message: 'Connection error. Is the backend running?');
    }
  }

  // POST /api/recipes â€” ingredient list + user prefs â†’ recipe list
  static Future<List<Recipe>> getRecipes(
    List<String> ingredients, {
    Map<String, dynamic>? prefs,
  }) async {
    try {
      final body = <String, dynamic>{'ingredients': ingredients};
      if (prefs != null && prefs.isNotEmpty) body['prefs'] = prefs;
      final res = await http.post(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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

  // GET /api/recipe/:id â€” single recipe detail
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

  // POST /api/chat â€” message â†’ AI reply
  static Future<String> sendChat(String message, {List<Map<String, String>>? history}) async {
    try {
      final body = <String, dynamic>{'message': message};
      if (history != null && history.isNotEmpty) body['history'] = history;
      final res = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data']['reply'] as String;
      return 'Sorry, I could not get a response. Try again!';
    } catch (_) {
      return 'Connection error. Is the backend running?';
    }
  }

  // POST /api/goals â€” weight/height/age/goal â†’ TDEE + targets
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

  // GET /api/favorites â€” returns saved recipes for user
  static Future<List<Recipe>> getFavorites() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/favorites?user_id=$_uid'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return (data['data'] as List).map((r) => Recipe.fromJson(r)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/favorites â€” save a recipe as favorite
  static Future<void> addFavorite(int recipeId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/favorites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _uid, 'recipe_id': recipeId}),
      );
    } catch (_) {}
  }

  // GET /api/favorites/check/<id> â€” is recipe saved?
  static Future<bool> isFavorite(int recipeId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/favorites/check/$recipeId?user_id=$_uid'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') return data['data']['is_favorite'] as bool;
      return false;
    } catch (_) {
      return false;
    }
  }

  // POST or DELETE /api/favorites â€” toggle favorite state, returns new state
  static Future<bool> toggleFavorite(int recipeId) async {
    final currently = await isFavorite(recipeId);
    try {
      if (currently) {
        await http.delete(Uri.parse('$baseUrl/api/favorites/$recipeId?user_id=$_uid'));
        return false;
      } else {
        await http.post(
          Uri.parse('$baseUrl/api/favorites'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': _uid, 'recipe_id': recipeId}),
        );
        return true;
      }
    } catch (_) {
      return currently;
    }
  }

  // GET /api/history â€” returns cooking history for user
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/history?user_id=$_uid'));
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // GET /api/history/stats â€” aggregated stats
  static Future<Map<String, int>> getHistoryStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/history/stats?user_id=$_uid'));
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
      await http.delete(Uri.parse('$baseUrl/api/history/$id?user_id=$_uid'));
    } catch (_) {}
  }

  static Future<void> clearHistory() async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/history?user_id=$_uid'));
    } catch (_) {}
  }

  static Future<void> logHistory({
    required String ingredientNames,
    String actionType = 'cooked',
    int recipeCount = 1,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _uid,
          'action_type': actionType,
          'ingredient_names': ingredientNames,
          'recipe_count': recipeCount,
        }),
      );
    } catch (_) {}
  }
}

