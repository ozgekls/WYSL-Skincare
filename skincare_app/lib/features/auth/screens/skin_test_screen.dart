// lib/features/auth/screens/skin_test_screen.dart

import 'package:flutter/material.dart';
import 'package:skincare_app/data/services/api_service.dart';
// MainNavigationScreen'in gerçek yolunu buraya yaz.
// Projenizde neredeyse o import'u düzenle:
import 'package:skincare_app/features/home/screens/home_screen.dart';
import 'package:skincare_app/main.dart';

// ignore: unused_import — MainNavigationScreen varsa aşağıdakini kullan:
// import 'package:skincare_app/widgets/main_navigation_screen.dart';

class SkinTestScreen extends StatefulWidget {
  final int userId;
  const SkinTestScreen({super.key, required this.userId});

  @override
  State<SkinTestScreen> createState() => _SkinTestScreenState();
}

class _SkinTestScreenState extends State<SkinTestScreen> {
  int _currentQuestionIndex = 0;

  // Puanlama sayaçları
  int oilyScore = 0;
  int dryScore = 0;
  int sensitivityScore = 0;
  int pigmentationScore = 0;
  int agingScore = 0;

  final List<Map<String, dynamic>> _questions = [
    // ─── BÖLÜM 1: YAĞLANMA (Oiliness) ───────────────────────────────────────
    {
      'id': 1,
      'category': 'oiliness',
      'question':
          'Sabah cildinizi yıkadıktan birkaç saat sonra cildiniz nasıl görünür?',
      'options': [
        {
          'text': 'Parlak ve yağlı görünür, yüzümü yıkamak isterim',
          'oily': 4,
          'dry': 0,
        },
        {'text': 'Hafif parlak, özellikle T-bölgesinde', 'oily': 3, 'dry': 1},
        {'text': 'Normal görünür, ne yağlı ne kuru', 'oily': 2, 'dry': 2},
        {
          'text': 'Gergin ve sıkışmış hisseder, yer yer pullanma olabilir',
          'oily': 0,
          'dry': 4,
        },
      ],
    },
    {
      'id': 2,
      'category': 'oiliness',
      'question':
          'Cildinizi yıkadıktan sonra nemlendirici kullanmazsanız cildiniz nasıl hisseder?',
      'options': [
        {'text': 'Rahat hisseder, neme ihtiyaç duymaz', 'oily': 4, 'dry': 0},
        {'text': 'Biraz gergin ama idare edebilir', 'oily': 2, 'dry': 2},
        {
          'text': 'Belirgin şekilde gergin ve rahatsız hisseder',
          'oily': 1,
          'dry': 3,
        },
        {
          'text': 'Çok gergin, pullanma ve çekilme hissi olur',
          'oily': 0,
          'dry': 4,
        },
      ],
    },
    {
      'id': 3,
      'category': 'oiliness',
      'question':
          'Özellikle alın, burun ve çene bölgeniz (T-bölgesi) gün içinde nasıl görünür?',
      'options': [
        {'text': 'Sürekli parlak ve yağlı görünür', 'oily': 4, 'dry': 0},
        {
          'text': 'Öğleden sonra belirgin şekilde parlıyor',
          'oily': 3,
          'dry': 1,
        },
        {
          'text': 'Hafif parlama olabilir ama belirgin değil',
          'oily': 2,
          'dry': 2,
        },
        {'text': 'Hiç parlamaz, aksine kurur', 'oily': 0, 'dry': 4},
      ],
    },
    {
      'id': 4,
      'category': 'oiliness',
      'question':
          'Fondöten veya pudra kullandığınızda gün sonunda görünümü nasıl olur?',
      'options': [
        {'text': 'Makyaj dağılır, yağlanır ve topaklanır', 'oily': 4, 'dry': 0},
        {'text': 'Özellikle T-bölgesinde biraz kayar', 'oily': 3, 'dry': 1},
        {'text': 'Büyük ölçüde kalıcı ve düzgün görünür', 'oily': 2, 'dry': 2},
        {
          'text': 'Makyaj kurur ve çatlar, pullanma olabilir',
          'oily': 0,
          'dry': 4,
        },
      ],
    },
    {
      'id': 5,
      'category': 'oiliness',
      'question': 'Gözenekleriniz hakkında ne düşünüyorsunuz?',
      'options': [
        {'text': 'Gözeneklerim çok büyük ve belirgin', 'oily': 4, 'dry': 0},
        {
          'text': 'Burun ve alın bölgemde gözenekler görünür',
          'oily': 3,
          'dry': 1,
        },
        {
          'text': 'Gözeneklerim orta büyüklükte, çok dikkat çekmez',
          'oily': 2,
          'dry': 2,
        },
        {
          'text': 'Gözeneklerim çok küçük, neredeyse görünmez',
          'oily': 0,
          'dry': 4,
        },
      ],
    },

    // ─── BÖLÜM 2: KURULUK / NEMLENDİRME (Hydration) ─────────────────────────
    {
      'id': 6,
      'category': 'hydration',
      'question': 'Kış aylarında veya soğuk havalarda cildiniz nasıl hisseder?',
      'options': [
        {'text': 'Fark etmem, cildin nem değişmez', 'oily': 4, 'dry': 0},
        {
          'text': 'Biraz gerginleşir ama kısa sürede geçer',
          'oily': 2,
          'dry': 2,
        },
        {
          'text': 'Belirgin kuruluk ve gerginlik hissederim',
          'oily': 1,
          'dry': 3,
        },
        {
          'text': 'Çok kurur, pullanma ve çatlama olabilir',
          'oily': 0,
          'dry': 4,
        },
      ],
    },
    {
      'id': 7,
      'category': 'hydration',
      'question': 'Cildinizi temizledikten hemen sonra nasıl hisseder?',
      'options': [
        {'text': 'Rahat ve temiz hisseder', 'oily': 4, 'dry': 0},
        {
          'text': 'Hafif gerginlik hissederim, kısa sürede geçer',
          'oily': 2,
          'dry': 2,
        },
        {
          'text': 'Belirgin gerginlik, nemlendirici hemen gerekir',
          'oily': 1,
          'dry': 3,
        },
        {
          'text': 'Çok gergin ve rahatsız, nemlendirici olmadan duramam',
          'oily': 0,
          'dry': 4,
        },
      ],
    },
    {
      'id': 8,
      'category': 'hydration',
      'question': 'Vücudunuzun cildini (el, bacak gibi) nasıl tanımlarsınız?',
      'options': [
        {
          'text': 'Yumuşak ve nemli, nadiren losyon gerekir',
          'oily': 4,
          'dry': 0,
        },
        {'text': 'Bazen biraz kurur ama genelde iyi', 'oily': 2, 'dry': 2},
        {'text': 'Sık sık losyon kullanmam gerekir', 'oily': 1, 'dry': 3},
        {
          'text': 'Her gün nemlendirici kullanmadan çok kuru hisseder',
          'oily': 0,
          'dry': 4,
        },
      ],
    },
    {
      'id': 9,
      'category': 'hydration',
      'question': 'Cildinizde ince çizgiler veya pullanma ne sıklıkla görülür?',
      'options': [
        {'text': 'Hiç görmem', 'oily': 4, 'dry': 0},
        {'text': 'Nadiren, sadece çok soğuk havalarda', 'oily': 3, 'dry': 1},
        {'text': 'Zaman zaman, özellikle kışın', 'oily': 1, 'dry': 3},
        {'text': 'Sık sık, hemen hemen her gün', 'oily': 0, 'dry': 4},
      ],
    },

    // ─── BÖLÜM 3: HASSASİYET (Sensitivity) ──────────────────────────────────
    {
      'id': 10,
      'category': 'sensitivity',
      'question':
          'Yeni bir cilt bakım ürünü denediğinizde ne sıklıkla reaksiyon görürsünüz?',
      'options': [
        {
          'text': 'Hiç reaksiyon görmem, her ürünü kullanabilirim',
          'sensitivity': 0,
        },
        {'text': 'Nadiren hafif bir kızarıklık olabilir', 'sensitivity': 1},
        {'text': 'Zaman zaman kaşıntı veya yanma hissederim', 'sensitivity': 2},
        {
          'text': 'Çoğu üründe reaksiyon görürüm, çok dikkatli seçmeliyim',
          'sensitivity': 3,
        },
      ],
    },
    {
      'id': 11,
      'category': 'sensitivity',
      'question': 'Güneşe maruz kaldığınızda cildiniz nasıl tepki verir?',
      'options': [
        {'text': 'Hiç etkilenmez, güneşte rahat olurum', 'sensitivity': 0},
        {
          'text': 'Uzun süreli maruziyette hafif kızarıklık olabilir',
          'sensitivity': 1,
        },
        {'text': 'Kısa sürede kızarır ve hassaslaşır', 'sensitivity': 2},
        {
          'text': 'Çok çabuk yanar, güneşe karşı çok hassasım',
          'sensitivity': 3,
        },
      ],
    },
    {
      'id': 12,
      'category': 'sensitivity',
      'question':
          'Koku içeren ürünler (parfüm, losyon gibi) cildinizi etkiler mi?',
      'options': [
        {
          'text': 'Hayır, koku içeren ürünleri sorunsuz kullanırım',
          'sensitivity': 0,
        },
        {
          'text': 'Çok yoğun kokularda bazen hafif reaksiyon olabilir',
          'sensitivity': 1,
        },
        {
          'text': 'Koku içeren ürünlerde sık sık tahriş yaşarım',
          'sensitivity': 2,
        },
        {'text': 'Koku içeren hiçbir ürünü kullanamam', 'sensitivity': 3},
      ],
    },
    {
      'id': 13,
      'category': 'sensitivity',
      'question': 'Cildinizde kızarıklık, kaşıntı veya yanma ne sıklıkla olur?',
      'options': [
        {'text': 'Hiç olmaz', 'sensitivity': 0},
        {'text': 'Nadiren, yılda birkaç kez', 'sensitivity': 1},
        {'text': 'Ayda birkaç kez', 'sensitivity': 2},
        {'text': 'Haftada birkaç kez veya sürekli', 'sensitivity': 3},
      ],
    },
    {
      'id': 14,
      'category': 'sensitivity',
      'question':
          'Stres, yorgunluk veya hormonal değişimlerde cildiniz nasıl tepki verir?',
      'options': [
        {'text': 'Hiç etkilenmez', 'sensitivity': 0},
        {'text': 'Çok hafif değişim olabilir', 'sensitivity': 1},
        {'text': 'Sivilce veya kızarıklık çıkar', 'sensitivity': 2},
        {'text': 'Ciltte çok belirgin bozulmalar olur', 'sensitivity': 3},
      ],
    },

    // ─── BÖLÜM 4: PİGMENTASYON (Pigmentation) ────────────────────────────────
    {
      'id': 15,
      'category': 'pigmentation',
      'question':
          'Sivilce veya yaralanma sonrası cildinizde koyu leke kalır mı?',
      'options': [
        {'text': 'Hayır, izler çok çabuk kaybolur', 'pigmentation': 0},
        {'text': 'Bazen hafif pembe iz kalır ama geçer', 'pigmentation': 1},
        {
          'text': 'Genellikle kahverengi leke kalır, birkaç ay sürer',
          'pigmentation': 2,
        },
        {
          'text': 'Her zaman koyu leke kalır, çok uzun süre geçmez',
          'pigmentation': 3,
        },
      ],
    },
    {
      'id': 16,
      'category': 'pigmentation',
      'question': 'Güneşe maruz kaldığınızda cildiniz nasıl tepki verir?',
      'options': [
        {'text': 'Hiç yanmadan bronzlaşırım', 'pigmentation': 0},
        {'text': 'Önce hafif yanar sonra bronzlaşırım', 'pigmentation': 1},
        {'text': 'Genellikle yanarım, az bronzlaşırım', 'pigmentation': 2},
        {'text': 'Her zaman yanarım, hiç bronzlaşmam', 'pigmentation': 3},
      ],
    },
    {
      'id': 17,
      'category': 'pigmentation',
      'question': 'Yüzünüzde düzensiz renk tonu veya lekeler var mı?',
      'options': [
        {'text': 'Hayır, cilt tonum çok eşit', 'pigmentation': 0},
        {'text': 'Çok az, neredeyse fark edilmez', 'pigmentation': 1},
        {'text': 'Evet, belirgin lekelerim var', 'pigmentation': 2},
        {
          'text': 'Evet, çok belirgin ve rahatsız edici lekelerim var',
          'pigmentation': 3,
        },
      ],
    },

    // ─── BÖLÜM 5: YAŞLANMA (Aging) ───────────────────────────────────────────
    {
      'id': 18,
      'category': 'aging',
      'question': 'Yaşınıza göre kırışıklık veya ince çizgi durumunuz nedir?',
      'options': [
        {'text': 'Yaşıma göre çok az veya hiç kırışıklık yok', 'aging': 0},
        {'text': 'Hafif ince çizgiler var, yaşıma uygun', 'aging': 1},
        {'text': 'Belirgin kırışıklıklar var', 'aging': 2},
        {
          'text': 'Çok belirgin kırışıklıklar, yaşımdan fazla gösteriyor',
          'aging': 3,
        },
      ],
    },
    {
      'id': 19,
      'category': 'aging',
      'question': 'Cildinizin genel sıkılığı ve elastikiyeti nasıl?',
      'options': [
        {'text': 'Cildim sıkı ve elastik', 'aging': 0},
        {'text': 'Biraz gevşeme var ama genel olarak iyi', 'aging': 1},
        {'text': 'Belirgin sarkma ve gevşeme var', 'aging': 2},
        {
          'text': 'Çok belirgin sarkma, cilt elastikiyetini kaybetmiş',
          'aging': 3,
        },
      ],
    },
  ];

  static const Map<String, String> _categoryLabels = {
    'oiliness': 'Yağlanma',
    'hydration': 'Nem & Kuruluk',
    'sensitivity': 'Hassasiyet',
    'pigmentation': 'Pigmentasyon',
    'aging': 'Yaşlanma',
  };

  static const Map<String, IconData> _categoryIcons = {
    'oiliness': Icons.water_drop_outlined,
    'hydration': Icons.opacity,
    'sensitivity': Icons.favorite_border,
    'pigmentation': Icons.wb_sunny_outlined,
    'aging': Icons.auto_awesome_outlined,
  };

  void _answerQuestion(Map<String, dynamic> option) {
    setState(() {
      final category =
          (_questions[_currentQuestionIndex]['category'] as String?) ?? '';

      if (category == 'oiliness' || category == 'hydration') {
        oilyScore += (option['oily'] as int? ?? 0);
        dryScore += (option['dry'] as int? ?? 0);
      } else if (category == 'sensitivity') {
        sensitivityScore += (option['sensitivity'] as int? ?? 0);
      } else if (category == 'pigmentation') {
        pigmentationScore += (option['pigmentation'] as int? ?? 0);
      } else if (category == 'aging') {
        agingScore += (option['aging'] as int? ?? 0);
      }

      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _finishTest();
      }
    });
  }

  void _finishTest() async {
    String resultSkinType;

    if (oilyScore >= 24) {
      resultSkinType = 'Yağlı';
    } else if (dryScore >= 24) {
      resultSkinType = 'Kuru';
    } else if (oilyScore >= 16 && dryScore >= 16) {
      resultSkinType = 'Karma';
    } else {
      resultSkinType = 'Normal';
    }

    if (sensitivityScore >= 8) {
      resultSkinType = 'Hassas $resultSkinType'.trim();
    }

    try {
      await ApiService.updateSkinType(widget.userId, resultSkinType);
      if (mounted) {
        _showResultDialog(resultSkinType);
      }
    } catch (e) {
      debugPrint('Hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sonuç kaydedilirken bir hata oluştu.')),
        );
      }
    }
  }

  void _showResultDialog(String type) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Test Tamamlandı! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cilt tipiniz: $type',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _scoreLine('Yağlılık', oilyScore, 36),
            _scoreLine('Kuruluk', dryScore, 36),
            _scoreLine('Hassasiyet', sensitivityScore, 15),
            _scoreLine('Pigmentasyon', pigmentationScore, 9),
            _scoreLine('Yaşlanma', agingScore, 6),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // dialog'u kapat
              // Tüm önceki route'ları temizleyerek HomeScreen'e git
              // ÖNEMLİ: Eğer MainNavigationScreen varsa aşağıdaki satırı
              // home_screen yerine main_navigation_screen ile değiştir
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => MainNavigation(userId: widget.userId),
                ),
                (route) => false,
              );
            },
            child: const Text('Uygulamaya Başla'),
          ),
        ],
      ),
    );
  }

  Widget _scoreLine(String label, int score, int max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            '$score / $max',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];
    final category = (currentQuestion['category'] as String?) ?? '';
    final options =
        (currentQuestion['options'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cilt Tipi Testi'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _categoryIcons[category] ?? Icons.help_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _categoryLabels[category] ?? category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentQuestionIndex + 1} / ${_questions.length}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                currentQuestion['question'] as String,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _answerQuestion(option),
                      child: Text(
                        option['text'] as String,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                        textAlign: TextAlign.left,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
