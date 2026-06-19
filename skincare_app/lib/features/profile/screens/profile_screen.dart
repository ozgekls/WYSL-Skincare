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

      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var p in products) {
        final type = p['routine_type'] ?? '';
        if (type == 'analyzed') continue;

        final name = p['product_name']?.toString().trim() ?? 'İsimsiz';
        final lowerName = name.toLowerCase();

        if (!grouped.containsKey(lowerName)) {
          grouped[lowerName] = [];
        }
        grouped[lowerName]!.add(Map<String, dynamic>.from(p));
      }

      final List<Map<String, dynamic>> displayList = [];
      grouped.forEach((key, list) {
        final types = list.map((e) => e['routine_type'] as String).toSet();

        String displayType = '';
        if (types.contains('Sabah Rutini') && types.contains('Akşam Rutini')) {
          displayType = 'Sabah & Akşam';
        } else if (types.contains('Sabah Rutini')) {
          displayType = 'Sabah Rutini';
        } else if (types.contains('Akşam Rutini')) {
          displayType = 'Akşam Rutini';
        } else if (types.contains('liked')) {
          displayType = 'liked';
        } else if (types.contains('disliked')) {
          displayType = 'disliked';
        } else {
          displayType = types.isNotEmpty ? types.first : '';
        }

        final representative = Map<String, dynamic>.from(list.first);
        representative['display_type'] = displayType;
        representative['original_records'] = list;

        displayList.add(representative);
      });

      setState(() {
        _pastProducts = displayList;
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

    final originalRecords =
        product['original_records'] as List<Map<String, dynamic>>?;
    final allTypes =
        originalRecords?.map((e) => e['routine_type'] as String).toList() ?? [];

    bool isLiked = !allTypes.contains('disliked');

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

                  try {
                    if (originalRecords != null && originalRecords.isNotEmpty) {
                      if (isLiked) {
                        bool hasRoutine =
                            allTypes.contains('Sabah Rutini') ||
                            allTypes.contains('Akşam Rutini');

                        if (hasRoutine) {
                          for (var record in originalRecords) {
                            await ApiService.updateProduct(
                              widget.userId!,
                              record['id'] as int,
                              nameController.text,
                              record['routine_type'],
                            );
                          }
                        } else {
                          await ApiService.updateProduct(
                            widget.userId!,
                            originalRecords.first['id'] as int,
                            nameController.text,
                            'liked',
                          );
                          for (int i = 1; i < originalRecords.length; i++) {
                            await ApiService.deleteProduct(
                              widget.userId!,
                              originalRecords[i]['id'] as int,
                            );
                          }
                        }
                      } else {
                        await ApiService.updateProduct(
                          widget.userId!,
                          originalRecords.first['id'] as int,
                          nameController.text,
                          'disliked',
                        );
                        for (int i = 1; i < originalRecords.length; i++) {
                          await ApiService.deleteProduct(
                            widget.userId!,
                            originalRecords[i]['id'] as int,
                          );
                        }
                      }
                    } else {
                      await ApiService.updateProduct(
                        widget.userId!,
                        product['id'] as int,
                        nameController.text,
                        isLiked ? 'liked' : 'disliked',
                      );
                    }

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
      case 'Sabah & Akşam':
        return '☀️ Sabah & Akşam';
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
      case 'Sabah & Akşam':
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
                                    product['display_type'] ??
                                    product['routine_type'] ??
                                    '';
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
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                                  final originalRecords =
                                                      product['original_records']
                                                          as List<
                                                            Map<String, dynamic>
                                                          >?;
                                                  try {
                                                    if (originalRecords !=
                                                            null &&
                                                        originalRecords
                                                            .isNotEmpty) {
                                                      for (var record
                                                          in originalRecords) {
                                                        await ApiService.deleteProduct(
                                                          widget.userId!,
                                                          record['id'] as int,
                                                        );
                                                      }
                                                    } else {
                                                      await ApiService.deleteProduct(
                                                        widget.userId!,
                                                        product['id'] as int,
                                                      );
                                                    }
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

                    if (widget.userId != null) ...[
                      const SizedBox(height: 24),
                      UserIngredientsSection(userId: widget.userId!),
                      const SizedBox(height: 16),
                      const ConflictCheckSection(),
                    ],
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

class UserIngredientsSection extends StatefulWidget {
  final int userId;
  const UserIngredientsSection({super.key, required this.userId});

  @override
  State<UserIngredientsSection> createState() => _UserIngredientsSectionState();
}

class _UserIngredientsSectionState extends State<UserIngredientsSection> {
  bool _isLoading = true;
  List<dynamic> _unsafeIngredients = [];
  List<dynamic> _flaggedIngredients = [];

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  void _loadIngredients() async {
    try {
      final data = await ApiService.getSafeIngredients(widget.userId);
      if (mounted) {
        setState(() {
          _unsafeIngredients = data['unsafe_ingredients'] ?? [];
          _flaggedIngredients = data['flagged_ingredients'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.teal,
          ),
        ),
      );
    }

    if (_unsafeIngredients.isEmpty && _flaggedIngredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.security_rounded, color: Colors.teal),
        title: const Text(
          'Kişisel İçerik Profilim',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${_unsafeIngredients.length} tehlikeli, ${_flaggedIngredients.length} şüpheli madde',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          if (_unsafeIngredients.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '❌ Kesinlikle Kaçınmanız Gerekenler',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _unsafeIngredients.map<Widget>((item) {
                    return Chip(
                      backgroundColor: Colors.red[50],
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      label: Text(
                        item['ingredient_name'] ?? '',
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          if (_flaggedIngredients.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '⚠️ Dikkat Etmeniz Gerekenler (Sınırda)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _flaggedIngredients.map<Widget>((item) {
                    return Chip(
                      backgroundColor: Colors.orange[50],
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      label: Text(
                        item['ingredient_name'] ?? '',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ConflictCheckSection extends StatefulWidget {
  const ConflictCheckSection({super.key});

  @override
  State<ConflictCheckSection> createState() => _ConflictCheckSectionState();
}

class _ConflictCheckSectionState extends State<ConflictCheckSection> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _conflicts = [];
  bool _hasSearched = false;

  void _analyzeConflicts() async {
    if (_textController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final result = await ApiService.checkIngredientConflicts(
        _textController.text,
      );
      setState(() {
        _conflicts = result['conflicts'] ?? [];
      });
    } catch (e) {
      debugPrint('Çakışma analiz hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.science_outlined, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Hızlı İçerik Çakışma Testi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Aynı rutinde birleştirmek istediğiniz aktif içerikleri aralarına virgül koyarak yazın.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Örn: Retinol, Vitamin C, Niacinamide',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _analyzeConflicts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Test Et',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
            if (_hasSearched && !_isLoading) ...[
              const SizedBox(height: 14),
              if (_conflicts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Harika! Bu içerikler aynı rutinde güvenle kullanılabilir.',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _conflicts.map<Widget>((conflict) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.block_outlined,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${conflict['ingredient_a']} ❌ ${conflict['ingredient_b']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 22),
                            child: Text(
                              conflict['description'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[800],
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
