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
  Future<List<dynamic>>? _userRoutines;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // API'den kullanıcı profilini ve rutinleri çekiyoruz
  void _fetchData() {
    if (widget.userId != null) {
      _userProfile = ApiService.getUserProfile(widget.userId!);
      _userRoutines = ApiService.getUserRoutine(widget.userId!);
    } else {
      _userProfile = null;
      _userRoutines = null;
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
                      "Merhaba,\n${user.username}", // İSİM ARTIK VERİTABANINDAN GELİYOR
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainGreen,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChip(
                      user.skinTypeLabel,
                    ), // CİLT TİPİ ARTIK VERİTABANINDAN GELİYOR
                    const SizedBox(height: 25),

                    // Uyarı Kutusu (Bunu ileride dinamik yapacağız, şimdilik senin tasarımın duruyor)
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
                    _buildSectionTitle("SABAH RUTİNİ"),
                    // Veritabanındaki 'Sabah Rutini' verilerini yolluyoruz
                    _buildDynamicRoutineList("Sabah Rutini"),

                    const SizedBox(height: 30),
                    _buildSectionTitle("GECE RUTİNİ"),
                    // Veritabanında 'Akşam Rutini' diye kaydettiğimiz için buraya onu gönderiyoruz
                    _buildDynamicRoutineList("Akşam Rutini"),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // --- ARTIK DİNAMİK LİSTE ---
  Widget _buildDynamicRoutineList(String targetRoutineType) {
    return SizedBox(
      height: 160,
      child: FutureBuilder<List<dynamic>>(
        future: _userRoutines,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Rutinler yüklenemedi."));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Henüz ürün eklenmedi.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Gelen verileri filtrele (Sadece sabah olanlar veya sadece akşam olanlar)
          final routineProducts = snapshot.data!
              .where((product) => product['routine_type'] == targetRoutineType)
              .toList();

          if (routineProducts.isEmpty) {
            return const Center(
              child: Text(
                "Bu rutine henüz ürün eklenmedi.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: routineProducts.length,
            itemBuilder: (context, index) {
              final product = routineProducts[index];

              // Backend'den gelen statüyü (Güvenli/Dikkat) alıyoruz
              String status = product['status'] ?? "İnceleniyor";

              return _buildRoutineCard(
                "${index + 1}. ADIM",
                product['product_name'] ?? 'Bilinmeyen Ürün',
                "Kişisel Ürün",
                status, // Eskiden "Serum/Temizleyici" yazan yere Analiz Sonucunu koydum!
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoutineCard(
    String step,
    String name,
    String brand,
    String category,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 15, top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            brand,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              category, // Buraya artık "Güvenli" veya "Dikkat" yazacak
              style: TextStyle(
                fontSize: 10,
                // Eğer "Dikkat" gelirse yazıyı turuncu, "Güvenli" gelirse yeşil yapıyoruz
                color: category == "Dikkat"
                    ? Colors.orange
                    : (category == "Güvenli" ? Colors.green : Colors.grey),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
