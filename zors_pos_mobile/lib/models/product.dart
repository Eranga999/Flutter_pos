class Product {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final String? barcode;
  final String? image;
  final String? supplier;
  final double? discount;
  final String? size;
  final bool? dryfood;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    required this.minStock,
    this.barcode,
    this.image,
    this.supplier,
    this.discount,
    this.size,
    this.dryfood,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? '',
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      minStock: json['minStock'] ?? 5,
      barcode: json['barcode'],
      image: json['image'],
      supplier: json['supplier'],
      discount: (json['discount'] ?? 0).toDouble(),
      size: json['size'],
      dryfood: json['dryfood'] ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'category': category,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'stock': stock,
      'minStock': minStock,
      'barcode': barcode,
      'image': image,
      'supplier': supplier,
      'discount': discount,
      'size': size,
      'dryfood': dryfood,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    // Only include _id when present; let server generate otherwise
    if (id.isNotEmpty) {
      map['_id'] = id;
    }
    return map;
  }
}
