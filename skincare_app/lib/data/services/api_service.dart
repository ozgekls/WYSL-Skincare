import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:skincare_app/data/models/user_model.dart';

class ApiService {
  // ÖNEMLİ NOT:
  // Windows masaüstü / Web: 'http://127.0.0.1:8000'
  // Android Emülatör      : 'http://10.0.2.2:8000'

  static const String baseUrl = 'http://127.0.0.1:8000';

  // --- ÜRÜN ANALİZİ (ID ile) ---
  static Future<List<dynamic>> getProductAnalysis(
    int userId,
    int productId,
  ) async {
    final url = Uri.parse('$baseUrl/products/analyze/$userId/$productId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Analiz yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // --- KAYIT OL ---
  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/users/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Kayıt başarısız');
    }
  }

  // --- GİRİŞ YAP ---
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/users/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email.trim(), 'password': password.trim()}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Giriş başarısız. Bilgilerinizi kontrol edin.');
    }
  }

  // --- CİLT TİPİ GÜNCELLEME ---
  static Future<void> updateSkinType(int userId, String skinType) async {
    final url = Uri.parse('$baseUrl/users/update-skin-type');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'skin_type': skinType}),
    );
    if (response.statusCode != 200) {
      throw Exception('Cilt tipi güncellenemedi.');
    }
  }

  // --- KULLANICI PROFİLİ ---
  static Future<UserModel> getUserProfile(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return UserModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Kullanıcı bilgileri yüklenemedi.');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // --- RUTİNE / GEÇMİŞE ÜRÜN EKLE ---
  /// routineType: 'Sabah Rutini' | 'Akşam Rutini' | 'liked' | 'disliked' | 'analyzed'
  static Future<void> addProductToRoutine(
    int userId,
    String routineType,
    String productName,
    String ingredients,
  ) async {
    final url = Uri.parse('$baseUrl/users/add-product');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'routine_type': routineType,
        'product_name': productName,
        'ingredients': ingredients,
      }),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['detail'] ?? 'Bilinmeyen bir veritabanı hatası',
      );
    }
  }

  // --- RUTİNİ GETİR ---
  static Future<List<dynamic>> getUserRoutine(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/routine');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Rutin yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // --- GEÇMİŞ ÜRÜNLER (liked / disliked) ---
  static Future<List<dynamic>> getPastProducts(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/past-products');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Ürünler yüklenemedi');
  }

  // --- ANALİZ GEÇMİŞİ (analyzed) ---
  static Future<List<dynamic>> getAnalysisHistory(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/analysis-history');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Analiz geçmişi yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // --- ANALİZ GEÇMİŞİNDEN SİL ---
  static Future<void> deleteAnalysisHistory(int userId, int productId) async {
    final url = Uri.parse('$baseUrl/users/$userId/analysis-history/$productId');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Silinemedi');
    }
  }

  // --- İÇERİK ANALİZİ (metin bazlı) ---
  static Future<List<dynamic>> analyzeIngredients(
    int userId,
    String ingredientsText,
  ) async {
    final url = Uri.parse('$baseUrl/products/analyze-text');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'ingredients_text': ingredientsText,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Analiz yapılamadı');
  }

  // --- ÜRÜN GÜNCELLE ---
  static Future<void> updateProduct(
    int userId,
    int productId,
    String productName,
    String routineType,
  ) async {
    final url = Uri.parse('$baseUrl/users/$userId/products/$productId');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'product_name': productName,
        'routine_type': routineType,
      }),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Güncelleme başarısız');
    }
  }

  // --- ÜRÜN SİL ---
  static Future<void> deleteProduct(int userId, int productId) async {
    final url = Uri.parse('$baseUrl/users/$userId/products/$productId');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Silme başarısız');
    }
  }
}
