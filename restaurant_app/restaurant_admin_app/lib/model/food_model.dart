class Food {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl; // This is the variable name in Dart
  final String category;

  Food({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? "",
      price: double.parse(json['price'].toString()),
      imageUrl: json['image_url'] ?? "", // Matches SQL image_url
      category: json['category'] ?? "Main",
    );
  }
}
