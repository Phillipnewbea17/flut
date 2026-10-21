import '../utils/manila_time.dart';

enum PurchaseCategory { medicine, food, transport, groceries, other }

extension PurchaseCategoryInfo on PurchaseCategory {
  String get label {
    switch (this) {
      case PurchaseCategory.medicine:
        return 'Medicine';
      case PurchaseCategory.food:
        return 'Restaurant';
      case PurchaseCategory.transport:
        return 'Transport';
      case PurchaseCategory.groceries:
        return 'Groceries';
      case PurchaseCategory.other:
        return 'Other';
    }
  }

  static PurchaseCategory parse(String? name) {
    return PurchaseCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => PurchaseCategory.other,
    );
  }
}

/// One line in the purchase booklet.
class PurchaseEntry {
  final String id;
  final DateTime date;
  final String store;
  final String item;
  final PurchaseCategory category;
  final double price;
  final double amountPaid;

  const PurchaseEntry({
    required this.id,
    required this.date,
    required this.store,
    required this.item,
    required this.category,
    required this.price,
    required this.amountPaid,
  });

  double get saved => price - amountPaid;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'store': store,
        'item': item,
        'category': category.name,
        'price': price,
        'amountPaid': amountPaid,
      };

  factory PurchaseEntry.fromJson(Map<String, dynamic> json) {
    return PurchaseEntry(
      id: json['id'] as String? ?? '',
      date: parseServerTime(json['date'] as String?) ?? DateTime.now(),
      store: json['store'] as String? ?? '',
      item: json['item'] as String? ?? '',
      category: PurchaseCategoryInfo.parse(json['category'] as String?),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// All purchases, newest first, with simple totals.
class PurchaseBooklet {
  final List<PurchaseEntry> entries;

  const PurchaseBooklet(this.entries);

  double get totalSaved => entries.fold<double>(0, (sum, e) => sum + e.saved);

  double savedInMonth(DateTime month) => entries
      .where((e) => e.date.year == month.year && e.date.month == month.month)
      .fold<double>(0, (sum, e) => sum + e.saved);
}
