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
      setState(() {
        _routineProducts = data;
      });
    } catch (e) {
      debugPrint('Rutin yüklenemedi: $e');
    } finally {
      setState(() => _isLoadingRoutine = false);
    }
  }

  // --- ÜRÜN EKLEME (Geçmişten Seç veya Yeni Ekle) ---
  void _showAddRoutineProduct(String routineType) {
    final nameController = TextEditingController();
    final ingredientsController = TextEditingController();

    bool isManualMode = false;
    List<Map<String, dynamic>> pastProducts = [];
    bool isLoading = true;
    Map<String, dynamic>? selectedProduct;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            ApiService.getPastProducts(widget.userId!)
                .then((data) {
                  if (context.mounted) {
                    setDialogState(() {
                      final Map<String, Map<String, dynamic>> unique = {};
                      for (var p in data) {
                        final name = p['product_name']?.toString().trim() ?? '';
                        if (name.isNotEmpty) {
                          unique[name.toLowerCase()] =
                              Map<String, dynamic>.from(p);
                        }
                      }
                      pastProducts = unique.values.toList();
                      isLoading = false;

                      if (pastProducts.isEmpty) {
                        isManualMode = true;
                      }
                    });
                  }
                })
                .catchError((_) {
                  if (context.mounted) {
                    setDialogState(() {
                      isLoading = false;
                      isManualMode = true;
                    });
                  }
                });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "$routineType'ne Ekle",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: isLoading
                ? const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mainGreen,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pastProducts.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(
                                    child: Text('Geçmişten Seç'),
                                  ),
                                  selected: !isManualMode,
                                  onSelected: (val) => setDialogState(
                                    () => isManualMode = false,
                                  ),
                                  selectedColor: AppColors.mainGreen,
                                  labelStyle: TextStyle(
                                    color: !isManualMode
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Yeni Ekle')),
                                  selected: isManualMode,
                                  onSelected: (val) =>
                                      setDialogState(() => isManualMode = true),
                                  selectedColor: AppColors.mainGreen,
                                  labelStyle: TextStyle(
                                    color: isManualMode
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),

                        if (!isManualMode && pastProducts.isNotEmpty)
                          DropdownButtonFormField<Map<String, dynamic>>(
                            decoration: InputDecoration(
                              labelText: 'Ürün Seçin',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            isExpanded: true,
                            value: selectedProduct,
                            hint: const Text('Kayıtlı ürünlerden seçin...'),
                            items: pastProducts.map((p) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: p,
                                child: Text(
                                  p['product_name'] ?? 'İsimsiz',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() => selectedProduct = val);
                            },
                          ),

                        if (isManualMode || pastProducts.isEmpty) ...[
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
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        String finalName = '';
                        String finalIngredients = '';

                        if (!isManualMode && selectedProduct != null) {
                          finalName = selectedProduct!['product_name'] ?? '';
                          finalIngredients =
                              selectedProduct!['ingredients_text'] ?? '';
                        } else if (isManualMode || pastProducts.isEmpty) {
                          finalName = nameController.text.trim();
                          finalIngredients = ingredientsController.text.trim();
                        }

                        if (finalName.isEmpty) return;

                        try {
                          await ApiService.addProductToRoutine(
                            widget.userId!,
                            routineType,
                            finalName,
                            finalIngredients,
                          );
                          if (context.mounted) Navigator.pop(context);
                          await _loadRoutine();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Eklenemedi: $e')),
                            );
                          }
                        }
                      },
                child: const Text(
                  'Ekle',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
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
              return RefreshIndicator(
                color: AppColors.mainGreen,
                onRefresh: () async {
                  await _loadRoutine();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                "Cilt sorunlarınız ciddi boyutta ise dermatoloğa başvurmayı unutmayınız!",
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
          height: 200, // 📌 GÜNCELLENDİ: Liste yüksekliği 200 olarak ayarlandı
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
                    final ingredientCount = ingredientsText.isEmpty
                        ? 0
                        : ingredientsText.split(',').length;

                    return Container(
                      width:
                          160, // 📌 GÜNCELLENDİ: Kart genişliği 160 olarak ayarlandı
                      margin: const EdgeInsets.only(
                        right: 15,
                        top: 10,
                        bottom: 5,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: 5,
                            bottom: 10, // Konumu biraz daha aşağıya çektik
                            child: Opacity(
                              opacity: 0.09, // Transparanlık ayarı
                              child: const Text(
                                '',
                                style: TextStyle(
                                  fontSize: 100, // emoji boyutunu büyüttük
                                ),
                              ),
                            ),
                          ),

                          // Kartın İçerik Katmanı
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      '${index + 1}. ADIM',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
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
                                            await ApiService.updateProduct(
                                              widget.userId!,
                                              product['id'] as int,
                                              product['product_name'] ??
                                                  'İsimsiz', // Mevcut adını koruyoruz
                                              'liked', // Rutin etiketini ezerek aktif rutinden düşürüyoruz
                                            );
                                            await _loadRoutine();
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
                              const SizedBox(height: 8),

                              Text(
                                productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF2D4A31),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const Spacer(),

                              // 2. DOKUNUŞ: İçerik Sayısı Alanı
                              if (ingredientCount > 0) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.science_outlined,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$ingredientCount içerik',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],

                              // 3. DOKUNUŞ: Premium Çerçeveli Durum Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'Dikkat'
                                      ? Colors.orange.withOpacity(0.1)
                                      : (status == 'Güvenli'
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: status == 'Dikkat'
                                        ? Colors.orange.withOpacity(0.3)
                                        : (status == 'Güvenli'
                                              ? Colors.green.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.2)),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      status == 'Dikkat'
                                          ? Icons.warning_amber_rounded
                                          : (status == 'Güvenli'
                                                ? Icons.check_circle_outline
                                                : Icons.help_outline),
                                      size: 10,
                                      color: status == 'Dikkat'
                                          ? Colors.orange[800]
                                          : (status == 'Güvenli'
                                                ? Colors.green[700]
                                                : Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: status == 'Dikkat'
                                            ? Colors.orange[800]
                                            : (status == 'Güvenli'
                                                  ? Colors.green[700]
                                                  : Colors.grey[600]),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
