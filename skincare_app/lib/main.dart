import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skincare_app/data/services/api_service.dart';
import 'package:skincare_app/features/auth/screens/login_screen.dart';
import 'core/constants/colors.dart';
import 'features/home/screens/home_screen.dart';
import 'features/analysis/screens/analysis_screen.dart';
import 'features/profile/screens/profile_screen.dart';

void main() {
  runApp(const SkincareApp());
}

class SkincareApp extends StatelessWidget {
  const SkincareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Georgia',
      ),
      home: const _AuthGate(),
    );
  }
}

// Otomatik giriş kapısı
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    final email = prefs.getString('saved_email') ?? '';
    final password = prefs.getString('saved_password') ?? '';

    if (!remember || email.isEmpty) {
      // Kayıtlı oturum yok, login ekranına git
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    // Kaydedilmiş bilgilerle otomatik giriş dene
    try {
      final result = await ApiService.login(email, password);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigation(userId: result['user_id']),
          ),
        );
      }
    } catch (_) {
      // Otomatik giriş başarısız, bilgileri temizle ve login'e git
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kontrol yapılırken yükleniyor ekranı
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int? userId; // Girişten gelen ID'yi burada karşılıyoruz
  const MainNavigation({super.key, this.userId});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0; // Uygulama Ana Sayfa (0) ile başlasın

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomeScreen(userId: widget.userId), // 0. Sekme
      AnalysisScreen(userId: widget.userId), // 1. Sekme
      ProfileScreen(userId: widget.userId), // 2. Sekme
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, "Ana Sayfa", 0),
            _buildNavItem(Icons.search, "Keşfet", 1),
            _buildNavItem(Icons.person, "Profil", 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.lightGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.mainGreen : Colors.grey,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppColors.mainGreen : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
