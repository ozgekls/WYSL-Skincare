// lib/data/models/user_model.dart

class UserModel {
  final int userId;
  final String username;
  final String email;
  final String? skinType;

  const UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.skinType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      skinType: json['skin_type'] as String?,
    );
  }

  /// Cilt tipini Türkçe etiket olarak döndürür
  String get skinTypeLabel {
    switch (skinType?.toLowerCase()) {
      case 'oily':
        return 'Yağlı Cilt';
      case 'dry':
        return 'Kuru Cilt';
      case 'combination':
        return 'Kombine Cilt';
      case 'normal':
        return 'Normal Cilt';
      case 'sensitive':
        return 'Hassas Cilt';
      default:
        return skinType != null ? skinType! : 'Belirlenmedi';
    }
  }

  /// Kullanıcı adından baş harf üretir (avatar için)
  String get initials {
    if (username.isEmpty) return '?';
    return username[0].toUpperCase();
  }
}
