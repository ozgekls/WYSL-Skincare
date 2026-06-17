import 'package:flutter/material.dart';
import 'package:skincare_app/data/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class AnalysisScreen extends StatefulWidget {
  final int? userId;

  const AnalysisScreen({super.key, this.userId});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();

  List<dynamic> _analysisHistory = [];
  bool _isLoadingHistory = false;
  bool _isAnalyzing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(_pulseController);

    if (widget.userId != null) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ingredientsController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (widget.userId == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final history = await ApiService.getAnalysisHistory(widget.userId!);
      setState(() => _analysisHistory = history);
    } catch (e) {
      debugPrint('Geçmiş yüklenemedi: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  void _pickImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImagePickerSheet(),
    );
  }

  Future<void> _pickAndScanImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(pickedFile.path);
    final recognized = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final scannedText = recognized.text;
    if (scannedText.isNotEmpty && mounted) {
      final filteredText = _extractIngredientsText(scannedText);
      _ingredientsController.text = filteredText;

      _showManualEntryDialog(clearFields: false);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metin okunamadı, manuel girin.')),
        );
      }
    }
  }

  String _extractIngredientsText(String rawText) {
    String extractedText = rawText;

    // --- 1. AŞAMA: BAŞLANGIÇ NOKTASINI BUL ---
    // Türkçe İ/ı/I harf karmaşasını ve "İçeriğinde" gibi kelimeleri atlamak için özel regex
    final RegExp startRegExp = RegExp(
      r'(?:[iİıI]ngredients?|[iİıI][cçCÇ][iİıI]ndek[iİıI]ler|[iİıI][cçCÇ]er[iİıI]k(?:ler)?|[iİıI][cçCÇ]er[iİıI][gğGĞ][iİıI]|[fF]orm[uüUÜ]l|[cC]omposition)(?![a-zA-ZğüşıöçĞÜŞİÖÇ])\s*[:\-]*\s*\n*(.*)',
      caseSensitive: false,
      dotAll: true,
    );

    final match = startRegExp.firstMatch(extractedText);

    if (match != null && match.group(1) != null) {
      // Başlığı bulduysa sonrasını al
      extractedText = match.group(1)!;
    } else {
      // B PLANI: Eğer başlığı bulamazsa (satıcı yazmamışsa), "AQUA" veya "WATER" kelimesini arayıp oradan başla!
      final fallbackMatch = RegExp(
        r'\b(AQUA|WATER|SU)\b',
        caseSensitive: false,
      ).firstMatch(extractedText);
      if (fallbackMatch != null) {
        extractedText = extractedText.substring(fallbackMatch.start);
      }
    }

    // --- 2. AŞAMA: BİTİŞ NOKTASINI BUL (Sonrasını Çöpe At) ---
    final stopPhrases = [
      r'iyi\s+ve\s+sağlıklı',
      r'sağlıklı\s+günler',
      r'iyi\s+günler',
      r'sevgilerimizle',
      r'saat\s+içinde\s+cevaplandı',
      r'satıcıya\s+sor',
      r'sepete\s+ekle',
      r'soruyu\s+beğen',
      r'kullanıma\s+uygundur',
      r'doktorunuza\s+danış',
      r'\[bi\s*\d+\]', // Bioderma formül kodları
      r'cevaplandı',
      r'stoklarımız', // "Stoklarımız yenilenmiştir" vb.
    ];

    for (var phrase in stopPhrases) {
      final stopMatch = RegExp(
        phrase,
        caseSensitive: false,
      ).firstMatch(extractedText);
      if (stopMatch != null) {
        extractedText = extractedText.substring(0, stopMatch.start);
      }
    }

    // --- 3. AŞAMA: TEMİZLEME VE VİRGÜLLE AYIRMA ---
    extractedText = extractedText.replaceAll('\n', ', ');
    extractedText = extractedText.replaceAll('.', ',');
    extractedText = extractedText.replaceAll('•', ',');
    extractedText = extractedText.replaceAll(';', ',');
    // NOT: Tireleri (-) sildirmedim çünkü C12-15 veya PEG-10 gibi önemli kimyasal formülleri bozuyor.

    extractedText = extractedText.replaceAll(RegExp(r',+'), ',');

    // --- 4. AŞAMA: İÇİNE KARIŞAN ÇÖPLERİ CIKARTMA (Filtre) ---
    final badWords = [
      'merhaba',
      'teşekkür',
      'günler',
      'dileriz',
      'efendim',
      'ürün',
      'içeriği',
      'soruyu',
      'beğen',
      'saat',
      'içinde',
      'cevaplandı',
      'satici',
      'sepete',
      'ekle',
      'trendyol',
      'müşteri',
      'hizmetleri',
      'türkiye',
      'stok',
      'yenilenmiştir',
      'kampanya',
      'sipariş',
      'soru',
      'cevap',
      'havlu',
      'bilek',
    ];

    extractedText = extractedText
        .split(',')
        .map((e) => e.trim())
        .where((e) {
          if (e.isEmpty || e.length <= 2) return false;

          final lowerE = e.toLowerCase();

          // Tarih formatlarını (Örn: 22 Temmuz) yok et
          if (RegExp(
            r'\d{1,2}\s+(ocak|şubat|subat|mart|nisan|mayıs|mayis|haziran|temmuz|ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)',
            caseSensitive: false,
          ).hasMatch(lowerE))
            return false;

          // Saat formatlarını (Örn: 2:53, 09:50) yok et
          if (RegExp(r'\d{1,2}:\d{2}').hasMatch(lowerE)) return false;

          // ÖsO, ÖS, AM, PM gibi zaman kelimelerini yok et
          if (RegExp(
            r'\b(ös|öö|am|pm|öso)\b',
            caseSensitive: false,
          ).hasMatch(lowerE))
            return false;

          // E-ticaret kelimelerini barındıran kısımları toptan yok et
          for (var word in badWords) {
            if (lowerE.contains(word)) return false;
          }

          return true;
        })
        .join(', ');

    return extractedText;
  }

  Widget _buildImagePickerSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'İçerik Listesi Yükle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D4A31),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ürünün içerik listesinin fotoğrafını çek\nveya galerinizden seçin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _pickOptionCard(
                  Icons.camera_alt_outlined,
                  'Fotoğraf Çek',
                  const Color(0xFFE8F5E9),
                  const Color(0xFF4CAF50),
                  () {
                    Navigator.pop(context);
                    _pickAndScanImage(ImageSource.camera);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pickOptionCard(
                  Icons.photo_library_outlined,
                  'Galeriden Seç',
                  const Color(0xFFE3F2FD),
                  const Color(0xFF2196F3),
                  () {
                    Navigator.pop(context);
                    _pickAndScanImage(ImageSource.gallery);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Manuel Gir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A5D4E),
                side: const BorderSide(color: Color(0xFF4A5D4E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showManualEntryDialog();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pickOptionCard(
    IconData icon,
    String label,
    Color bg,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog({bool clearFields = true}) {
    if (clearFields) {
      _productNameController.clear();
      _ingredientsController.clear();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'İçerik Analizi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D4A31),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _productNameController,
                decoration: InputDecoration(
                  labelText: 'Ürün Adı',
                  hintText: 'Örn: CeraVe Moisturizing Cream',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ingredientsController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'İçerik Listesi',
                  hintText:
                      'Water, Glycerin, Niacinamide, Ceramide NP...\n\nİçerikleri virgülle ayırarak yapıştırın',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                  ),
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.list_alt_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.science_outlined, color: Colors.white),
                  label: const Text(
                    'Analizi Başlat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A5D4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (_ingredientsController.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    await _runAnalysis(
                      _productNameController.text.trim().isEmpty
                          ? 'İsimsiz Ürün'
                          : _productNameController.text.trim(),
                      _ingredientsController.text.trim(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAnalysis(String productName, String ingredients) async {
    if (widget.userId == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final results = await ApiService.analyzeIngredients(
        widget.userId!,
        ingredients,
      );

      debugPrint("API'DEN GELEN HAM VERİ: $results");

      await ApiService.addProductToRoutine(
        widget.userId!,
        'analyzed',
        productName,
        ingredients,
      );

      await _loadHistory();

      if (mounted) {
        _showResultsSheet(productName, results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Analiz hatası: $e')));
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showResultsSheet(String productName, List<dynamic> results) {
    final danger = results.where((r) => r['status'] == 'danger').length;
    final warning = results.where((r) => r['status'] == 'warning').length;
    final safe = results.where((r) => r['status'] == 'safe').length;
    final unknown = results.where((r) => r['status'] == 'unknown').length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F2ED),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.science_outlined,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D4A31),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${results.length} içerik analiz edildi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _summaryChip('$danger', 'Tehlikeli', Colors.red),
                        const SizedBox(width: 8),
                        _summaryChip('$warning', 'Dikkat', Colors.orange),
                        const SizedBox(width: 8),
                        _summaryChip(
                          '$safe',
                          'Güvenli',
                          const Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 8),
                        _summaryChip('$unknown', 'Bilinmiyor', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final item = results[i];
                    return _buildIngredientResultCard(item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 9, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientResultCard(Map<String, dynamic> item) {
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
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle_outline;
        statusLabel = 'Güvenli';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusLabel = 'Bilinmiyor';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['ingredient_name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2D4A31),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['reason'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                if (item['comedogenic_score'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _miniScoreBar(
                        'Comedogenic',
                        item['comedogenic_score'] as int? ?? 0,
                        Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _miniScoreBar(
                        'Irritasyon',
                        item['irritation_score'] as int? ?? 0,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniScoreBar(String label, int score, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        ...List.generate(5, (i) {
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < score ? color : Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ],
    );
  }

  void _showHistoryDetail(Map<String, dynamic> item) async {
    if (widget.userId == null) return;

    final ingredients = item['ingredients_text'] ?? '';
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu ürün için içerik bilgisi yok.')),
      );
      return;
    }

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
                CircularProgressIndicator(color: Color(0xFF4CAF50)),
                SizedBox(height: 16),
                Text('Yeniden analiz ediliyor...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final results = await ApiService.analyzeIngredients(
        widget.userId!,
        ingredients,
      );
      if (mounted) {
        Navigator.pop(context);
        _showResultsSheet(item['product_name'] ?? 'Ürün', results);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _deleteHistoryItem(int productId) async {
    try {
      await ApiService.deleteProduct(widget.userId!, productId);
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analiz geçmişinden silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _duplicateToRoutine(
    String productName,
    String ingredients,
    String type,
  ) async {
    try {
      await ApiService.addProductToRoutine(
        widget.userId!,
        type,
        productName,
        ingredients,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$productName listeye kopyalandı!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showAddToPastDialog(String productName, String ingredients) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Geçmiş Ürünlere Ekle",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Cildiniz bu ürünle anlaştı mı?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _duplicateToRoutine(productName, ingredients, 'disliked');
            },
            child: const Text(
              "❌ Anlaşamadı",
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _duplicateToRoutine(productName, ingredients, 'liked');
            },
            child: const Text(
              "✅ Anlaştı",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KEŞFEDİN 🔬',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'İçerik\nAnalizörü',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D4A31),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Herhangi bir ürünün içeriklerini analiz edin',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: GestureDetector(
                  onTap: _isAnalyzing ? null : _pickImage,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _isAnalyzing ? 1.0 : _pulseAnimation.value,
                      child: child,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A5240), Color(0xFF4A6B52)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3A5240).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _isAnalyzing
                          ? const Column(
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'İçerikler analiz ediliyor...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Veritabanı ile karşılaştırılıyor',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.document_scanner_outlined,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'İçerik Listesi Tara',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ürün fotoğrafı çek veya\niçerikleri manuel gir',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _actionPill(
                                      Icons.camera_alt_outlined,
                                      'Fotoğraf',
                                    ),
                                    const SizedBox(width: 8),
                                    _actionPill(Icons.edit, 'Manuel Gir'),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ANALİZ GEÇMİŞİ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_analysisHistory.isNotEmpty)
                      Text(
                        '${_analysisHistory.length} ürün',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isLoadingHistory)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  ),
                ),
              )
            else if (_analysisHistory.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 40,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz analiz yapılmadı',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Yukarıdaki butona tıklayarak\nilk analizinizi yapın',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = Map<String, dynamic>.from(
                      _analysisHistory[index],
                    );
                    return _buildHistoryCard(item);
                  }, childCount: _analysisHistory.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final productName = item['product_name'] ?? 'İsimsiz Ürün';
    final date = item['analysis_date'] ?? '';
    final ingredients = item['ingredients_text'] ?? '';
    final ingredientCount = ingredients.isEmpty
        ? 0
        : ingredients.split(',').length;
    final productId = item['id'] as int?;

    String dateLabel = '';
    try {
      final d = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inDays == 0) {
        dateLabel = 'Bugün';
      } else if (diff.inDays == 1) {
        dateLabel = 'Dün';
      } else if (diff.inDays < 7) {
        dateLabel = '${diff.inDays} gün önce';
      } else {
        dateLabel = '${d.day}.${d.month}.${d.year}';
      }
    } catch (_) {
      dateLabel = date.isNotEmpty ? date.substring(0, 10) : '';
    }

    return GestureDetector(
      onTap: () => _showHistoryDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🧴', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF2D4A31),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.format_list_bulleted,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$ingredientCount içerik',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) async {
                    if (value == 'sabah') {
                      await _duplicateToRoutine(
                        productName,
                        ingredients,
                        'Sabah Rutini',
                      );
                    } else if (value == 'aksam') {
                      await _duplicateToRoutine(
                        productName,
                        ingredients,
                        'Akşam Rutini',
                      );
                    } else if (value == 'gecmis') {
                      _showAddToPastDialog(productName, ingredients);
                    } else if (value == 'sil') {
                      if (productId != null) {
                        await _deleteHistoryItem(productId);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'sabah',
                      child: Row(
                        children: [
                          Text('☀️', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 8),
                          Text(
                            'Sabah Rutinine Ekle',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'aksam',
                      child: Row(
                        children: [
                          Text('🌙', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 8),
                          Text(
                            'Akşam Rutinine Ekle',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'gecmis',
                      child: Row(
                        children: [
                          Text('🕰️', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 8),
                          Text(
                            'Geçmiş Ürünlere Ekle',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sil',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sil',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F2ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF4A5D4E),
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
