class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.mrp,
    required this.imageUrl,
    required this.inStock,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
        mrp: (json['mrp'] as num?)?.toInt() ?? 0,
        imageUrl: json['imageUrl'] as String? ?? '',
        inStock: json['inStock'] as bool? ?? true,
      );

  final String id;
  final String name;
  final String unit;

  /// Whole rupees.
  final int price;
  final int mrp;
  final String imageUrl;
  final bool inStock;

  int get savings => mrp > price ? mrp - price : 0;

  /// Whole-number discount off MRP, e.g. 16 for ₹239 vs ₹285.
  int get discountPercent => mrp > 0 ? (savings * 100 / mrp).round() : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'mrp': mrp,
        'imageUrl': imageUrl,
        'inStock': inStock,
      };
}
