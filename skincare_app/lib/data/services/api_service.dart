import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:skincare_app/data/models/user_model.dart';
// UserModel'in bulunduğu yo

class ApiService {
  // ÖNEMLİ NOT:
  // Eğer Flutter'ı Windows masaüstünde veya Web'de çalıştırıyorsan adres: 'http://127.0.0.1:8000'
  // Eğer Android Emülatör kullanıyorsan adres: 'http://10.0.2.2:8000' olmalıdır!
  static const String baseUrl =
      'http://127.0.0.1:8000'; // Backend'in çalıştığı adresi buraya yazın

  // Ürün analizini getiren fonksiyon
  static Future<List<dynamic>> getProductAnalysis(
    int userId,
    int productId,
  ) async {
    final url = Uri.parse('$baseUrl/products/analyze/$userId/$productId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Gelen JSON verisini Flutter'ın anlayacağı Listeye çeviriyoruz
        return json.decode(response.body);
      } else {
        throw Exception('Analiz yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // --- KAYIT OL FONKSİYONU ---
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

  // --- GİRİŞ YAP FONKSİYONU ---
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

    print("Backend Status Code: ${response.statusCode}");
    print("Backend Response Body: ${response.body}");

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Giriş başarısız. Bilgilerinizi kontrol edin.');
    }
  }

  // --- CİLT TİPİ GÜNCELLEME FONKSİYONU ---
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

  // --- KULLANICI PROFİLİ GETİRME FONKSİYONU ---
  static Future<UserModel> getUserProfile(int userId) async {
    final url = Uri.parse(
      '$baseUrl/users/$userId',
    ); // Backend'deki kullanıcı getirme endpoint'in

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Gelen JSON verisini UserModel'e çeviriyoruz
        return UserModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Kullanıcı bilgileri yüklenemedi.');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // --- RUTİNE ÜRÜN EKLEME FONKSİYONU ---
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
      // Backend'in bize gönderdiği GERÇEK hatayı (detail) yakalıyoruz
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['detail'] ?? 'Bilinmeyen bir veritabanı hatası',
      );
    }
  }

  // --- RUTİNİ GETİRME FONKSİYONU ---
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

  // --- GEÇMİŞ ÜRÜNLERİ GETİR ---
  static Future<List<dynamic>> getPastProducts(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/past-products');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Ürünler yüklenemedi');
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
}
