import 'package:flutter/material.dart';

class AnalysisScreen extends StatefulWidget {
  final int? userId; // Giriş yapan kullanıcı ID'si

  const AnalysisScreen({super.key, this.userId});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Arka plan rengin
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. FOTOĞRAF YÜKLEME ALANI
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  // Kesik çizgi efekti (Bunu daha sonra dotted_border paketi ile geliştirebilirsin)
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.upload_rounded,
                        color: Color(0xFF4CAF50),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "İçerik listesi yükle",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Ürün fotoğrafı veya içerik\nlistesini buraya yükle",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D), // Koyu buton
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        // TODO: Kamera veya Galeri açma fonksiyonu buraya gelecek
                      },
                      child: const Text(
                        "Fotoğraf Seç",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 2. SON ANALİZ EDİLENLER BAŞLIĞI
              const Text(
                "SON ANALİZ EDİLEN",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // 3. ANALİZ KARTI ŞABLONU (Backend'den liste gelince FutureBuilder ile döngüye girecek)
              _buildAnalysisCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- İKİNCİ GÖRSELDEKİ KART TASARIMI ---
  Widget _buildAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Ürün Başlığı
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F0),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Vitamin C Suspension 23%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "The Ordinary · Serum",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Skorlar (Rozetler)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(
                "A+",
                "Uyum",
                const Color(0xFFE8F5E9),
                const Color(0xFF4CAF50),
              ),
              _buildBadge(
                "2/5",
                "Comedogen",
                const Color(0xFFFFF3E0),
                Colors.orange,
              ),
              _buildBadge(
                "Güvenli",
                "Cilt Tipin",
                const Color(0xFFE8F5E9),
                const Color(0xFF4CAF50),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF0F0F0), thickness: 1),
          const SizedBox(height: 12),

          // İçerik Listesi
          _buildIngredientRow(
            "Ascorbic Acid",
            "Güvenli",
            const Color(0xFF4CAF50),
            const Color(0xFFE8F5E9),
          ),
          const SizedBox(height: 12),
          _buildIngredientRow(
            "Propylene Glycol",
            "Dikkat",
            Colors.orange,
            const Color(0xFFFFF3E0),
          ),
          const SizedBox(height: 12),
          _buildIngredientRow(
            "Isopropyl Myristate",
            "Kaçın",
            Colors.redAccent,
            const Color(0xFFFFEBEE),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    String score,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            score,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(
    String name,
    String status,
    Color statusColor,
    Color bgColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
