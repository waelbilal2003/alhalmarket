// widgets/table_components.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// كلاس فلترة الأرقام العشرية الموجبة
class PositiveDecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // التحقق من أن النص يحتوي فقط على أرقام ونقطة عشرية
    final regex = RegExp(r'^[0-9]*\.?[0-9]*$');
    if (!regex.hasMatch(newValue.text)) {
      return oldValue;
    }

    // التحقق من وجود نقطة عشرية واحدة فقط
    final decimalCount = '.'.allMatches(newValue.text).length;
    if (decimalCount > 1) {
      return oldValue;
    }

    // منع الأرقام السالبة
    if (newValue.text.contains('-')) {
      return oldValue;
    }

    return newValue;
  }
}

// كلاس فلترة رقمين بدون فاصلة عشرية
class TwoDigitInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // التحقق من أن النص يحتوي فقط على أرقام
    final regex = RegExp(r'^[0-9]*$');
    if (!regex.hasMatch(newValue.text)) {
      return oldValue;
    }

    // منع الأرقام السالبة
    if (newValue.text.contains('-')) {
      return oldValue;
    }

    // منع أكثر من خانتين (رقمين)
    if (newValue.text.length > 2) {
      return oldValue;
    }

    return newValue;
  }
}

// كلاس لتثبيت رأس الجدول
class StickyTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  StickyTableHeaderDelegate({required this.child, this.height = 32.0});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(StickyTableHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

// خلية رأس الجدول
Widget buildTableHeaderCell(String text) {
  return Container(
    padding: const EdgeInsets.all(2),
    constraints: const BoxConstraints(minHeight: 30),
    alignment: Alignment.center,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
    ),
  );
}

// خلية المجموع - نسخة موحدة (للأرقام فقط)
Widget buildTotalCell(TextEditingController controller) {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    decoration: BoxDecoration(
      color: Colors.yellow[100],
    ),
    child: TextField(
      controller: controller,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
      ),
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      keyboardType: TextInputType.number,
      enabled: false,
      readOnly: true,
    ),
  );
}

// خلية المجموع - نسخة موحدة (للنصوص مثل "المجموع")
Widget buildTotalLabelCell(String label) {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    decoration: BoxDecoration(
      color: Colors.yellow[100],
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

// خلية الإجمالي غير القابلة للتعديل
Widget buildTotalValueCell(TextEditingController controller) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    alignment: Alignment.center,
    child: TextField(
      controller: controller,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
        hintText: '0.00',
        hintStyle: TextStyle(fontSize: 17, color: Colors.grey),
      ),
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      keyboardType: TextInputType.number,
      enabled: false,
      readOnly: true,
    ),
  );
}

// خلية الفوارغ - بنفس تنسيق نقدي/دين مع اللون الأزرق
Widget buildEmptiesCell({
  required String value,
  required VoidCallback onTap,
  required int rowIndex,
  required int colIndex,
  required Function(int, int) scrollToField,
}) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: InkWell(
      onTap: () {
        onTap();
        scrollToField(rowIndex, colIndex);
      },
      child: _buildEmptiesDisplay(value),
    ),
  );
}

// دالة مساعدة لعرض قيمة الفوارغ بنفس تنسيق نقدي/دين
Widget _buildEmptiesDisplay(String value) {
  switch (value) {
    case 'مع فوارغ':
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.fromARGB(255, 14, 82, 184),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(2),
          color: const Color.fromARGB(255, 14, 82, 184).withOpacity(0.05),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: const Center(
          child: Text(
            'مع فوارغ',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 14, 82, 184),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    case 'بدون فوارغ':
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.fromARGB(255, 14, 82, 184),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(2),
          color: const Color.fromARGB(255, 14, 82, 184).withOpacity(0.05),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: const Center(
          child: Text(
            'بدون فوارغ',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 14, 82, 184),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    default: // فارغ - اختيار
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'اختر',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
          ],
        ),
      );
  }
}
