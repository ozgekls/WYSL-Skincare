import 'package:flutter/material.dart';
import 'package:skincare_app/data/services/api_service.dart';
import 'package:skincare_app/features/home/screens/home_screen.dart';
import 'package:skincare_app/main.dart'; // MainNavigation neredeyse onu import et
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );

      // Giriş başarılı, Ana sayfaya yönlendir
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(userId: result['user_id']),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hoş geldin ${result['username']}!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Giriş başarısız, bilgilerinizi kontrol edin."),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "What's Your Skin Language?🫧🧴✨",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
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
                      onPressed: _handleLogin,
                      child: const Text("Giriş Yap"),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text("Henüz hesabın yok mu? Kayıt Ol"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
