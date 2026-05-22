import 'package:flutter/material.dart';
import 'package:skincare_app/data/services/api_service.dart';
import 'package:skincare_app/features/home/screens/home_screen.dart';
import 'package:skincare_app/features/auth/screens/skin_test_screen.dart';
import 'package:skincare_app/main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
      );

      // Kayıt başarılı! Şimdi Pop-up gösterme vaktidir.
      if (mounted) {
        _showSkinTypeDialog(result['user_id']);
      }
    } catch (e) {
      // Hata mesajını daha kullanıcı dostu gösterelim
      String errorMsg = e.toString();
      if (errorMsg.contains("UniqueViolation")) {
        errorMsg = "Bu kullanıcı adı veya e-posta zaten kullanımda!";
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSkinTypeDialog(int userId) {
    showDialog(
      context: context,
      barrierDismissible: false, // Boşluğa tıklayınca kapanmaz
      builder: (context) {
        return PopScope(
          canPop: false, // Geri tuşuyla kapanmasını engeller
          child: AlertDialog(
            title: const Text("Son Bir Adım! ✨"),
            content: const Text(
              "Kaydınız başarıyla oluşturuldu. Size uygun içerik analizi yapabilmemiz için cilt tipinizi belirlememiz gerekiyor.",
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 40),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Pop-up'ı kapat
                      _showSkinTypeSelection(userId); // Seçim listesini aç
                    },
                    child: const Text("Cilt Tipimi Biliyorum"),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(200, 40),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Pop-up'ı kapat

                      // DEĞİŞİKLİK: Test sayfasına yönlendirme aktif edildi
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SkinTestScreen(userId: userId),
                        ),
                      );
                    },
                    child: const Text("Bilmiyorum, Teste Başla"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSkinTypeSelection(int userId) {
    final skinTypes = ['Yağlı', 'Kuru', 'Karma', 'Hassas', 'Normal'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Cilt Tipinizi Seçin"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: skinTypes.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(skinTypes[index]),
                onTap: () async {
                  // Seçilen cilt tipini backend'e gönder
                  await ApiService.updateSkinType(userId, skinTypes[index]);
                  if (mounted) {
                    Navigator.pop(context); // Seçim ekranını kapat
                    // Ana sayfaya yönlendir
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainNavigation(userId: userId),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yeni Hesap Oluştur")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Ad Soyad"),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "E-posta"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Şifre"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleRegister,
                    child: const Text("Kayıt Ol"),
                  ),
          ],
        ),
      ),
    );
  }
}
