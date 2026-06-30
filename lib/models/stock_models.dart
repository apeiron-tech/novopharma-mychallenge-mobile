class StockExpiration {
  final String expirationDate; // YYYY-MM-DD
  final int quantity;

  StockExpiration({
    required this.expirationDate,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'expirationDate': expirationDate,
      'quantity': quantity,
    };
  }

  factory StockExpiration.fromJson(Map<String, dynamic> json) {
    return StockExpiration(
      expirationDate: json['expirationDate'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }
}

class ProductStockItem {
  final String productId;
  final String productName;
  int totalQuantity;
  List<StockExpiration> expirations;

  ProductStockItem({
    required this.productId,
    required this.productName,
    this.totalQuantity = 0,
    required this.expirations,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'totalQuantity': totalQuantity,
      'expirations': expirations.map((e) => e.toJson()).toList(),
    };
  }

  factory ProductStockItem.fromJson(Map<String, dynamic> json) {
    var expList = json['expirations'] as List? ?? [];
    return ProductStockItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      totalQuantity: json['totalQuantity'] ?? 0,
      expirations: expList.map((e) => StockExpiration.fromJson(e)).toList(),
    );
  }

  // Recalculates totalQuantity based on expirations
  void syncTotalQuantity() {
    if (expirations.isNotEmpty) {
      totalQuantity = expirations.fold(0, (sum, exp) => sum + exp.quantity);
    }
  }
}
