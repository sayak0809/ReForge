import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/quest.dart';
import '../models/weight.dart';
import '../models/food_log.dart';
import '../models/coach_message.dart';

class ApiService {
  /// Override at build/run time with:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
  /// Defaults to localhost, which only works when the backend runs on the
  /// same device as the app (e.g. an iOS simulator on this Mac).
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const String _userIdPrefKey = 'user_id';
  static int? _userId;

  static int get userId {
    final id = _userId;
    if (id == null) {
      throw StateError('No user set up yet — onboarding must complete before the API is used.');
    }
    return id;
  }

  static bool get hasUser => _userId != null;

  /// Call once at app startup, before runApp, to restore the signed-in user (if any).
  static Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt(_userIdPrefKey);
  }

  static Future<void> _persistUserId(int id) async {
    _userId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdPrefKey, id);
  }

  static String foodImageUrl(int imageId) => '$_baseUrl/food/images/$imageId';
  static String userPhotoUrl(int userId) => '$_baseUrl/users/$userId/photo';

  Future<User> createUser({
    required String name,
    required int age,
    required double heightCm,
    required double currentWeight,
    required double goalWeight,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'age': age,
        'height_cm': heightCm,
        'current_weight': currentWeight,
        'goal_weight': goalWeight,
      }),
    );
    if (response.statusCode == 200) {
      final user = User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      await ApiService._persistUserId(user.id);
      return user;
    }
    throw Exception('Failed to create profile: ${response.statusCode}');
  }

  Future<User> getUser() async {
    final response = await http.get(Uri.parse('$_baseUrl/users/$userId'));
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load user: ${response.statusCode}');
  }

  Future<List<UserQuest>> getTodayQuests() async {
    final response = await http.get(Uri.parse('$_baseUrl/quests/today/$userId'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = body['quests'] as List<dynamic>;
      return data
          .map((q) => UserQuest.fromJson(q as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load quests: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> completeQuest(int userQuestId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/quests/complete/$userQuestId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to complete quest: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> uncompleteQuest(int userQuestId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/quests/uncomplete/$userQuestId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to undo quest: ${response.statusCode}');
  }

  Future<List<WeightLog>> getWeightHistory() async {
    final response = await http.get(Uri.parse('$_baseUrl/weight/history/$userId'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = body['logs'] as List<dynamic>;
      return data
          .map((l) => WeightLog.fromJson(l as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load weight history: ${response.statusCode}');
  }

  Future<List<FoodLog>> getFoodHistory() async {
    final response = await http.get(Uri.parse('$_baseUrl/food/history/$userId'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = body['logs'] as List<dynamic>;
      return data
          .map((l) => FoodLog.fromJson(l as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load food history: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> logFood(List<int> imageBytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/food/log'));
    request.fields['user_id'] = userId.toString();
    request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log food: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> addFoodPhoto(int foodLogId, List<int> imageBytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/food/log/$foodLogId/add-photo'),
    );
    request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to add food photo: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> logFoodManual({
    required String name,
    required double calories,
    double? proteinG,
    double? fatG,
    double? carbsG,
    List<int>? imageBytes,
    String? filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/food/log/manual'));
    request.fields['user_id'] = userId.toString();
    request.fields['name'] = name;
    request.fields['calories'] = calories.toString();
    if (proteinG != null) request.fields['protein_g'] = proteinG.toString();
    if (fatG != null) request.fields['fat_g'] = fatG.toString();
    if (carbsG != null) request.fields['carbs_g'] = carbsG.toString();
    if (imageBytes != null && filename != null) {
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log meal: ${response.statusCode}');
  }

  Future<void> deleteFoodLog(int foodLogId) async {
    final response = await http.delete(Uri.parse('$_baseUrl/food/log/$foodLogId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete food log: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> logWeight(double weight) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/weight/log'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'weight': weight}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log weight: ${response.statusCode}');
  }

  Future<List<CoachMessage>> getCoachHistory() async {
    final response = await http.get(Uri.parse('$_baseUrl/coach/history/$userId'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = body['messages'] as List<dynamic>;
      return data.map((m) => CoachMessage.fromJson(m as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load coach history: ${response.statusCode}');
  }

  Future<String> sendCoachMessage(String message) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/coach/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'message': message}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['reply'] as String;
    }
    throw Exception('Coach failed to respond: ${response.statusCode}');
  }

  Future<List<String>> getQuestCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/quests/categories'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return List<String>.from(body['categories'] as List);
    }
    throw Exception('Failed to load quest categories: ${response.statusCode}');
  }

  Future<UserQuest> replaceQuest(int userQuestId, {String? preferredCategory}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/quests/$userQuestId/replace'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'preferred_category': preferredCategory}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return UserQuest.fromJson(body['quest'] as Map<String, dynamic>);
    }
    throw Exception('Failed to replace quest: ${response.statusCode}');
  }

  Future<User> updateProfile({
    String? name,
    int? age,
    double? heightCm,
    double? currentWeight,
    double? goalWeight,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (age != null) body['age'] = age;
    if (heightCm != null) body['height_cm'] = heightCm;
    if (currentWeight != null) body['current_weight'] = currentWeight;
    if (goalWeight != null) body['goal_weight'] = goalWeight;

    final response = await http.patch(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to update profile: ${response.statusCode}');
  }

  Future<void> uploadProfilePhoto(List<int> imageBytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/users/$userId/photo'));
    request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Failed to upload photo: ${response.statusCode}');
    }
  }
}
