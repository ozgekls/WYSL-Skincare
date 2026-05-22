class Ingredient {
  final String name;
  final String type;
  final String status;
  final String description;

  Ingredient({
    required this.name,
    required this.type,
    required this.status,
    required this.description,
  });

  // Backend'den (JSON) gelen veriyi modele çevirmek için
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'],
      type: json['type'],
      status: json['status'],
      description: json['description'],
    );
  }
}
