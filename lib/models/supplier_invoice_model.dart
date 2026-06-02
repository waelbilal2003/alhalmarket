/// سطر واحد في جدول المبيعات المجمّع (تجميع حسب المادة + السعر)
class GroupedSaleLine {
  final String material;
  final String price;
  final double totalCount; // إجمالي العدد
  final double totalStanding; // إجمالي الوزن (القائم)
  final double totalNet; // إجمالي الصافي
  final double totalValue; // إجمالي القيمة (الإجمالي)
  final int recordsCount; // عدد السجلات التي جُمّعت في هذا السطر

  GroupedSaleLine({
    required this.material,
    required this.price,
    required this.totalCount,
    required this.totalStanding,
    required this.totalNet,
    required this.totalValue,
    required this.recordsCount,
  });

  GroupedSaleLine copyWith({
    double? totalCount,
    double? totalStanding,
    double? totalNet,
    double? totalValue,
    int? recordsCount,
  }) {
    return GroupedSaleLine(
      material: material,
      price: price,
      totalCount: totalCount ?? this.totalCount,
      totalStanding: totalStanding ?? this.totalStanding,
      totalNet: totalNet ?? this.totalNet,
      totalValue: totalValue ?? this.totalValue,
      recordsCount: recordsCount ?? this.recordsCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material': material,
      'price': price,
      'totalCount': totalCount,
      'totalStanding': totalStanding,
      'totalNet': totalNet,
      'totalValue': totalValue,
      'recordsCount': recordsCount,
    };
  }

  factory GroupedSaleLine.fromJson(Map<String, dynamic> json) {
    return GroupedSaleLine(
      material: json['material'] ?? '',
      price: json['price'] ?? '',
      totalCount: (json['totalCount'] ?? 0).toDouble(),
      totalStanding: (json['totalStanding'] ?? 0).toDouble(),
      totalNet: (json['totalNet'] ?? 0).toDouble(),
      totalValue: (json['totalValue'] ?? 0).toDouble(),
      recordsCount: (json['recordsCount'] ?? 0).toInt(),
    );
  }
}

/// سطر مقارنة لكل مادة (المستلم مقابل المباع)
class SupplierComparisonLine {
  final String material;
  final double receiptCount; // العدد المستلم
  final double salesCount; // العدد المباع
  final double difference; // الفرق (المستلم - المباع)

  SupplierComparisonLine({
    required this.material,
    required this.receiptCount,
    required this.salesCount,
    required this.difference,
  });
}

/// الفاتورة الكاملة للمورد
class SupplierInvoice {
  final String supplierName;
  final String sValue;
  final String date;

  // جدول المبيعات المجمّع (حسب المادة + السعر)
  final List<GroupedSaleLine> groupedSales;

  // جدول المقارنة (مستلم مقابل مباع)
  final List<SupplierComparisonLine> comparison;

  // القيم المالية
  final double totalSalesValue; // إجمالي قيمة المبيعات
  double maloomPercent; // نسبة المعلوم (الكمسيون) %
  double maloomValue; // قيمة المعلوم = الإجمالي × النسبة / 100
  double loadValue; // الحمولة (مجلوبة من الاستلام، قابلة للتعديل)
  double paymentValue; // الدفعة (مجلوبة من الاستلام، قابلة للتعديل)
  double portageValue; // العتالة (إدخال يدوي → تُسجّل في الصندوق)

  SupplierInvoice({
    required this.supplierName,
    required this.sValue,
    required this.date,
    required this.groupedSales,
    required this.comparison,
    required this.totalSalesValue,
    this.maloomPercent = 0,
    this.maloomValue = 0,
    this.loadValue = 0,
    this.paymentValue = 0,
    this.portageValue = 0,
  });

  /// إجمالي المصاريف = المعلوم + الدفعة + الحمولة + العتالة
  double get totalExpenses =>
      maloomValue + paymentValue + loadValue + portageValue;

  /// صافي الفاتورة = إجمالي المبيعات - إجمالي المصاريف
  double get netInvoice => totalSalesValue - totalExpenses;
}
