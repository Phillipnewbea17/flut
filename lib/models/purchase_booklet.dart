import 'package:intl/intl.dart';

/// "₱1,234.50"
String formatPeso(double amount) =>
    NumberFormat.currency(locale: 'en', symbol: '₱', decimalDigits: 2)
        .format(amount);

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

  /// 20% for most things, 5% for basic groceries.
  double get discountRate => this == PurchaseCategory.groceries ? 0.05 : 0.20;

  /// Basic groceries keep their VAT; the others are VAT-free for seniors.
  bool get vatExempt => this != PurchaseCategory.groceries;

  static PurchaseCategory parse(String? name) {
    return PurchaseCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => PurchaseCategory.other,
    );
  }
}

class DiscountResult {
  final double price; // price on the tag (VAT included)
  final double vatRemoved;
  final double discount;
  final double amountToPay;
  final double rate;
  final bool vatExempt;

  const DiscountResult({
    required this.price,
    required this.vatRemoved,
    required this.discount,
    required this.amountToPay,
    required this.rate,
    required this.vatExempt,
  });

  double get saved => price - amountToPay;
}

/// The senior discount math, used by the calculator and the booklet.
class SeniorDiscount {
  SeniorDiscount._();

  static const double vatRate = 0.12;

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  static DiscountResult compute(double price, PurchaseCategory category) {
    final rate = category.discountRate;
    if (price <= 0) {
      return DiscountResult(
        price: 0,
        vatRemoved: 0,
        discount: 0,
        amountToPay: 0,
        rate: rate,
        vatExempt: category.vatExempt,
      );
    }
    if (category.vatExempt) {
      // Remove the 12% VAT first, then take the discount from what is left.
      final base = price / (1 + vatRate);
      final discount = base * rate;
      return DiscountResult(
        price: _round(price),
        vatRemoved: _round(price - base),
        discount: _round(discount),
        amountToPay: _round(base - discount),
        rate: rate,
        vatExempt: true,
      );
    }
    final discount = price * rate;
    return DiscountResult(
      price: _round(price),
      vatRemoved: 0,
      discount: _round(discount),
      amountToPay: _round(price - discount),
      rate: rate,
      vatExempt: false,
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
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
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
