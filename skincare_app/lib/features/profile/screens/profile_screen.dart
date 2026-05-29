import 'package:flutter/material.dart';
import 'package:skincare_app/data/services/api_service.dart';
import 'package:skincare_app/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skincare_app/features/auth/screens/login_screen.dart';
import 'package:skincare_app/features/auth/screens/skin_test_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  Future<UserModel>? _userProfile;

  List<Map<String, dynamic>> _pastProducts = [];
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _userProfile = ApiService.getUserProfile(widget.userId!);
      loadPastProducts();
    }
  }

  Future<void> loadPastProducts() async {
    if (widget.userId == null) return;
    setState(() => _isLoadingProducts = true);
    try {
      final products = await ApiService.getPastProducts(widget.userId!);
      setState(() {
        _pastProducts = products
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      });
    } catch (e) {
      debugPrint('Ürünler yüklenemedi: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _showAnalysisDialog(String productName, String ingredientsText) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF4CAF50)),
                SizedBox(height: 16),
                Text('İçerikler analiz ediliyor...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final analysis = await ApiService.analyzeIngredients(
        widget.userId!,
        ingredientsText,
      );

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: analysis.length,
                  itemBuilder: (context, index) {
                    final item = analysis[index];
                    final status = item['status'] ?? 'unknown';
                    Color statusColor;
                    IconData statusIcon;
                    String statusLabel;
                    switch (status) {
                      case 'danger':
                        statusColor = Colors.red;
                        statusIcon = Icons.dangerous_outlined;
                        statusLabel = 'Tehlikeli';
                        break;
                      case 'warning':
                        statusColor = Colors.orange;
                        statusIcon = Icons.warning_amber_outlined;
                        statusLabel = 'Dikkat';
                        break;
                      case 'safe':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle_outline;
                        statusLabel = 'Güvenli';
                        break;
                      default:
                        statusColor = Colors.grey;
                        statusIcon = Icons.help_outline;
                        statusLabel = 'Bilinmiyor';
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['ingredient_name'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['reason'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildAnalysisSummary(analysis),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Analiz yapılamadı: $e')));
    }
  }

  Widget _buildAnalysisSummary(List<dynamic> analysis) {
    int dangerCount = analysis.where((i) => i['status'] == 'danger').length;
    int warningCount = analysis.where((i) => i['status'] == 'warning').length;
    int safeCount = analysis.where((i) => i['status'] == 'safe').length;
    int unknownCount = analysis.where((i) => i['status'] == 'unknown').length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _summaryItem(dangerCount.toString(), 'Tehlikeli', Colors.red),
        _summaryItem(warningCount.toString(), 'Dikkat', Colors.orange),
        _summaryItem(safeCount.toString(), 'Güvenli', Colors.green),
        _summaryItem(unknownCount.toString(), 'Bilinmiyor', Colors.grey),
      ],
    );
  }

  Widget _summaryItem(String count, String label, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showAddPastProductDialog() {
    final nameController = TextEditingController();
    final ingredientsController = TextEditingController();
    bool isLiked = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Geçmiş Ürün Ekle",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Ürün Adı",
                      hintText: "Örn: Bioderma Sensibio",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: ingredientsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "İçerik Listesi",
                      hintText: "İçerikleri buraya yapıştırın...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Cildiniz bu ürünle anlaştı mı?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isLiked = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isLiked
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLiked
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "✅ Anlaştı",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isLiked = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isLiked
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isLiked
                                    ? Colors.red
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "❌ Anlaşamadı",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "İptal",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  try {
                    await ApiService.addProductToRoutine(
                      widget.userId!,
                      isLiked ? 'liked' : 'disliked',
                      nameController.text,
                      ingredientsController.text,
                    );
                    if (context.mounted) Navigator.pop(context);
                    await loadPastProducts();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ürün kaydedildi!")),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
                    }
                  }
                },
                child: const Text(
                  "Kaydet",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditPastProductDialog(int index, Map<String, dynamic> product) {
    final nameController = TextEditingController(
      text: product['product_name'] ?? product['name'] ?? '',
    );
    bool isLiked =
        product['routine_type'] == 'liked' ||
        product['routine_type'] == 'Sabah Rutini' ||
        product['routine_type'] == 'Akşam Rutini';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Ürünü Düzenle",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Ürün Adı",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Cildiniz bu ürünle anlaştı mı?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isLiked = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isLiked
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLiked
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "✅ Anlaştı",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isLiked = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isLiked
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isLiked
                                    ? Colors.red
                                    : Colors.transparent,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "❌ Anlaşamadı",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "İptal",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  final productId = product['id'] as int;
                  try {
                    await ApiService.updateProduct(
                      widget.userId!,
                      productId,
                      nameController.text,
                      isLiked ? 'liked' : 'disliked',
                    );
                    if (context.mounted) Navigator.pop(context);
                    await loadPastProducts();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  }
                },
                child: const Text(
                  "Güncelle",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Rutin tipini Türkçe etikete çevir
  String _routineLabel(String? routineType) {
    switch (routineType) {
      case 'liked':
        return '✅ Anlaştı';
      case 'disliked':
        return '❌ Anlaşamadı';
      case 'Sabah Rutini':
        return '☀️ Sabah';
      case 'Akşam Rutini':
        return '🌙 Akşam';
      case 'analyzed':
        return '🔬 Analiz';
      default:
        return routineType ?? '';
    }
  }

  Color _routineColor(String? routineType) {
    switch (routineType) {
      case 'liked':
      case 'Sabah Rutini':
      case 'Akşam Rutini':
        return Colors.green;
      case 'disliked':
        return Colors.red;
      case 'analyzed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile == null) {
      return const Scaffold(body: Center(child: Text("Lütfen giriş yapın.")));
    }

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<UserModel>(
          future: _userProfile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              final user = snapshot.data!;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- PROFİL BAŞLIĞI ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFFE8F5E9),
                              child: Text(
                                user.initials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                                Text(
                                  user.skinTypeLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF4CAF50),
                          size: 18,
                        ),
                        label: const Text(
                          "Cilt Testini Yenile",
                          style: TextStyle(color: Color(0xFF4CAF50)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SkinTestScreen(userId: widget.userId!),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- GEÇMİŞ ÜRÜNLERİM ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "GEÇMİŞ ÜRÜNLERİM",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF4CAF50),
                          ),
                          onPressed: _showAddPastProductDialog,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 180,
                      child: _isLoadingProducts
                          ? const Center(child: CircularProgressIndicator())
                          : _pastProducts.isEmpty
                          ? const Center(
                              child: Text(
                                "Henüz ürün eklenmedi.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pastProducts.length,
                              itemBuilder: (context, index) {
                                final product = _pastProducts[index];
                                final routineType =
                                    product['routine_type'] ?? '';
                                final productName =
                                    product['product_name'] ?? 'İsimsiz';
                                final ingredientsText =
                                    product['ingredients_text'] ?? '';
                                final color = _routineColor(routineType);
                                final label = _routineLabel(routineType);

                                return Container(
                                  width: 150,
                                  margin: const EdgeInsets.only(
                                    right: 15,
                                    bottom: 5,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              iconSize: 18,
                                              icon: const Icon(
                                                Icons.more_vert,
                                                color: Colors.grey,
                                              ),
                                              onSelected: (value) async {
                                                if (value == 'analyze') {
                                                  if (ingredientsText
                                                      .isNotEmpty) {
                                                    _showAnalysisDialog(
                                                      productName,
                                                      ingredientsText,
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'İçerik bilgisi yok.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } else if (value == 'edit') {
                                                  _showEditPastProductDialog(
                                                    index,
                                                    product,
                                                  );
                                                } else if (value == 'delete') {
                                                  final productId =
                                                      product['id'] as int;
                                                  try {
                                                    await ApiService.deleteProduct(
                                                      widget.userId!,
                                                      productId,
                                                    );
                                                    await loadPastProducts();
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Silinemedi: $e',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'analyze',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.science_outlined,
                                                        size: 16,
                                                        color: Color(
                                                          0xFF4CAF50,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Analiz Et',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit_outlined,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Düzenle',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete_outline,
                                                        size: 16,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Sil',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      if (ingredientsText.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => _showAnalysisDialog(
                                            productName,
                                            ingredientsText,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4CAF50,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              "🔬 Analiz Et",
                                              style: TextStyle(
                                                color: Color(0xFF4CAF50),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 40),

                    // --- İÇERİK ANALİZ RAPORU ---
                    const Text(
                      "İÇERİK ANALİZ RAPORU",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _pastProducts.isEmpty
                                  ? "Analiz motorunun çalışması için henüz yeterli veri yok."
                                  : "Ürün kartlarındaki '🔬 Analiz Et' butonuna tıklayarak içerik analizi yapabilirsiniz.",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text("Veri bulunamadı."));
          },
        ),
      ),
    );
  }
}
