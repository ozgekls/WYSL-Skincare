import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import 'package:skincare_app/data/services/api_service.dart';
import 'package:skincare_app/data/models/user_model.dart';

class HomeScreen extends StatefulWidget {
  final int? userId;
  const HomeScreen({super.key, this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<UserModel>? _userProfile;
  List<dynamic> _routineProducts = [];
  bool _isLoadingRoutine = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    if (widget.userId != null) {
      _userProfile = ApiService.getUserProfile(widget.userId!);
      _loadRoutine();
    }
  }

  Future<void> _loadRoutine() async {
    if (widget.userId == null) return;
    setState(() => _isLoadingRoutine = true);
    try {
      final data = await ApiService.getUserRoutine(widget.userId!);
      setState(() => _routineProducts = data);
    } catch (e) {
      debugPrint('Rutin yüklenemedi: $e');
    } finally {
      setState(() => _isLoadingRoutine = false);
    }
  }

  // --- ÜRÜN EKLEME ---
  void _showAddRoutineProduct(String routineType) {
    final nameController = TextEditingController();
    final ingredientsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "$routineType'ne Ürün Ekle",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Ürün Adı',
                  hintText: 'Örn: CeraVe Nemlendirici',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ingredientsController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'İçerik Listesi (opsiyonel)',
                  hintText: 'Water, Glycerin, Niacinamide...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mainGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await ApiService.addProductToRoutine(
                  widget.userId!,
                  routineType,
                  nameController.text.trim(),
                  ingredientsController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
                await _loadRoutine();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Eklenemedi: $e')));
                }
              }
            },
            child: const Text('Ekle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ÜRÜN DÜZENLEME ---
  void _showEditRoutineProduct(Map<String, dynamic> product) {
    final nameController = TextEditingController(
      text: product['product_name'] ?? '',
    );
    String selectedType = product['routine_type'] ?? 'Sabah Rutini';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ürünü Düzenle',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Ürün Adı',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Rutin Türü',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedType = 'Sabah Rutini'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedType == 'Sabah Rutini'
                              ? AppColors.lightGreen
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedType == 'Sabah Rutini'
                                ? AppColors.mainGreen
                                : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '☀️ Sabah',
                            style: TextStyle(
                              color: selectedType == 'Sabah Rutini'
                                  ? AppColors.mainGreen
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedType = 'Akşam Rutini'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedType == 'Akşam Rutini'
                              ? AppColors.lightGreen
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedType == 'Akşam Rutini'
                                ? AppColors.mainGreen
                                : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '🌙 Akşam',
                            style: TextStyle(
                              color: selectedType == 'Akşam Rutini'
                                  ? AppColors.mainGreen
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                try {
                  await ApiService.updateProduct(
                    widget.userId!,
                    product['id'] as int,
                    nameController.text.trim(),
                    selectedType,
                  );
                  if (context.mounted) Navigator.pop(context);
                  await _loadRoutine();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Güncellenemedi: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Güncelle',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- İÇERİK ANALİZİ ---
  void _showAnalysisDialog(String productName, String ingredientsText) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.mainGreen),
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
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      color: AppColors.mainGreen,
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    const Text(
                      "GÜNAYDIN ☀️",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "Merhaba,\n${user.username}",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainGreen,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChip(user.skinTypeLabel),
                    const SizedBox(height: 25),

                    // Uyarı kutusu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F0),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Uyarı: Son eklediğin ürün alerjen içeriğin olan Glycolic Acid barındırıyor.",
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    _buildRoutineSection("SABAH RUTİNİ", "Sabah Rutini"),
                    const SizedBox(height: 30),
                    _buildRoutineSection("GECE RUTİNİ", "Akşam Rutini"),
                    const SizedBox(height: 100),
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

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 4, backgroundColor: AppColors.mainGreen),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.mainGreen, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineSection(String title, String routineType) {
    final filtered = _routineProducts
        .where((p) => p['routine_type'] == routineType)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.mainGreen,
                size: 22,
              ),
              onPressed: () => _showAddRoutineProduct(routineType),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: _isLoadingRoutine
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? const Center(
                  child: Text(
                    "Bu rutine henüz ürün eklenmedi.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = Map<String, dynamic>.from(filtered[index]);
                    final productName = product['product_name'] ?? 'Bilinmeyen';
                    final status = product['status'] ?? 'İnceleniyor';
                    final ingredientsText = product['ingredients_text'] ?? '';

                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 15, top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${index + 1}. ADIM',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  iconSize: 16,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'analyze') {
                                      if (ingredientsText.isNotEmpty) {
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
                                              'Bu ürün için içerik bilgisi yok.',
                                            ),
                                          ),
                                        );
                                      }
                                    } else if (value == 'edit') {
                                      _showEditRoutineProduct(product);
                                    } else if (value == 'delete') {
                                      try {
                                        await ApiService.deleteProduct(
                                          widget.userId!,
                                          product['id'] as int,
                                        );
                                        await _loadRoutine();
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Silinemedi: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'analyze',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.science_outlined,
                                            size: 16,
                                            color: AppColors.mainGreen,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Analiz Et',
                                            style: TextStyle(fontSize: 13),
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
                                            style: TextStyle(fontSize: 13),
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
                          const SizedBox(height: 4),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                color: status == 'Dikkat'
                                    ? Colors.orange
                                    : (status == 'Güvenli'
                                          ? Colors.green
                                          : Colors.grey),
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
      ],
    );
  }
}
