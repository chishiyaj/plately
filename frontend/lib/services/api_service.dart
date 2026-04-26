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
}
