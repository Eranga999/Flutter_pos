class Discount {
  final String id;
  final String codeOrName; // can be code or name from backend
  final String? description;
  final String discountType; // 'percentage' | 'fixed'
  final double discountValue;
  final double? minAmount;
  final int? maxUses;
  final int usedCount;
  final bool isActive;
  final bool isGlobal;

  Discount({
    required this.id,
    required this.codeOrName,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minAmount,
    this.maxUses,
    required this.usedCount,
    required this.isActive,
    required this.isGlobal,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    // Support both legacy shape (code/discountType/discountValue) and
    // current backend shape (name/percentage/isGlobal).
    final hasLegacyFields =
        json.containsKey('discountType') || json.containsKey('discountValue');
    final discountType = hasLegacyFields
        ? (json['discountType'] ?? 'fixed') as String
        : 'percentage';
    final discountValue = hasLegacyFields
        ? (json['discountValue'] ?? 0).toDouble()
        : (json['percentage'] ?? 0).toDouble();
    final codeOrName = (json['code'] ?? json['name'] ?? '') as String;
    final isGlobal = (json['isGlobal'] ?? false) as bool;

    return Discount(
      id: json['_id'] ?? '',
      codeOrName: codeOrName,
      description: json['description'],
      discountType: discountType,
      discountValue: discountValue,
      minAmount: json['minAmount'] != null
          ? (json['minAmount'] as num).toDouble()
          : null,
      maxUses: json['maxUses'],
      usedCount: json['usedCount'] ?? 0,
      isActive: json['isActive'] ?? false,
      isGlobal: isGlobal,
    );
  }
}
