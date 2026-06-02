import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/invoices_service.dart';
import '../../services/box_storage_service.dart';
import '../../models/supplier_invoice_model.dart';
import '../../services/supplier_index_service.dart';
import '../../widgets/pdf_action_menu.dart';
import 'package:flutter/services.dart';
import '../../widgets/exit_button.dart';

class SupplierInvoicesScreen extends StatefulWidget {
  final String selectedDate;
  final String storeName;
  final String supplierName;
  // *** إضافة: قيمة "س" لشرط الفاتورة (المورد + س + التاريخ) ***
  // اختيارية بقيمة افتراضية فارغة حتى لا تُكسر أي استدعاءات قائمة للشاشة.
  final String sValue;
  // *** إضافة: اسم البائع لتسجيل سطر العتالة في الصندوق ***
  final String sellerName;

  const SupplierInvoicesScreen({
    Key? key,
    required this.selectedDate,
    required this.storeName,
    required this.supplierName,
    this.sValue = '',
    this.sellerName = '',
  }) : super(key: key);

  @override
  _SupplierInvoicesScreenState createState() => _SupplierInvoicesScreenState();
}

class _SupplierInvoicesScreenState extends State<SupplierInvoicesScreen> {
  final InvoicesService _invoicesService = InvoicesService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  final BoxStorageService _boxStorageService = BoxStorageService();

  late Future<SupplierInvoice> _invoiceFuture;
  double? _supplierBalance;

  // الفاتورة الحالية المحمّلة (تُستخدم للحسابات التفاعلية)
  SupplierInvoice? _invoice;

  // متحكمات حقول الإدخال
  final TextEditingController _maloomPercentController =
      TextEditingController();
  final TextEditingController _loadController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _portageController = TextEditingController();

  bool _savingPortage = false;

  @override
  void initState() {
    super.initState();
    _invoiceFuture = _loadInvoice();
    _loadSupplierBalance();
  }

  @override
  void dispose() {
    _maloomPercentController.dispose();
    _loadController.dispose();
    _paymentController.dispose();
    _portageController.dispose();
    super.dispose();
  }

  Future<SupplierInvoice> _loadInvoice() async {
    final invoice = await _invoicesService.generateSupplierInvoice(
      widget.selectedDate,
      widget.supplierName,
      widget.sValue,
    );
    _invoice = invoice;
    // تعبئة حقول الحمولة والدفعة بالقيم المجلوبة من الاستلام (قابلة للتعديل)
    _loadController.text = invoice.loadValue.toStringAsFixed(2);
    _paymentController.text = invoice.paymentValue.toStringAsFixed(2);
    return invoice;
  }

  Future<void> _loadSupplierBalance() async {
    final allSuppliers = await _supplierIndexService.getAllSuppliersWithData();
    for (var entry in allSuppliers.entries) {
      if (entry.value.name.toLowerCase() ==
          widget.supplierName.trim().toLowerCase()) {
        if (mounted) {
          setState(() {
            _supplierBalance = entry.value.balance;
          });
        }
        return;
      }
    }
  }

  // إعادة حساب القيم المالية عند تغيّر أي حقل إدخال
  void _recalculate() {
    final invoice = _invoice;
    if (invoice == null) return;

    final percent = double.tryParse(_maloomPercentController.text) ?? 0;
    final load = double.tryParse(_loadController.text) ?? 0;
    final payment = double.tryParse(_paymentController.text) ?? 0;
    final portage = double.tryParse(_portageController.text) ?? 0;

    setState(() {
      invoice.maloomPercent = percent;
      invoice.maloomValue =
          _invoicesService.calculateMaloom(invoice.totalSalesValue, percent);
      invoice.loadValue = load;
      invoice.paymentValue = payment;
      invoice.portageValue = portage;
    });
  }

  // حفظ سطر العتالة في يومية الصندوق
  Future<void> _savePortageToBox() async {
    final invoice = _invoice;
    if (invoice == null) return;

    if (invoice.portageValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال قيمة عتالة صحيحة')),
      );
      return;
    }

    setState(() => _savingPortage = true);

    final success = await _boxStorageService.addPortageEntry(
      date: widget.selectedDate,
      supplierName: widget.supplierName,
      portageValue: invoice.portageValue,
      sellerName: widget.sellerName,
      storeName: widget.storeName,
    );

    if (!mounted) return;
    setState(() => _savingPortage = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '✅ تم تسجيل العتالة في الصندوق'
            : '❌ فشل تسجيل العتالة في الصندوق'),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
      ),
    );
  }

  Future<Uint8List> _generatePdfBytes(SupplierInvoice invoice) async {
    final pdf = pw.Document();

    var arabicFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      arabicFont = pw.Font.courier();
    }

    // مجاميع جدول المبيعات المجمّع
    double salesTotalCount = 0,
        salesTotalStanding = 0,
        salesTotalNet = 0,
        salesTotalValue = 0;
    for (var line in invoice.groupedSales) {
      salesTotalCount += line.totalCount;
      salesTotalStanding += line.totalStanding;
      salesTotalNet += line.totalNet;
      salesTotalValue += line.totalValue;
    }

    final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);
    final PdfColor headerTextColor = PdfColors.white;
    final PdfColor rowEvenColor = PdfColors.white;
    final PdfColor salesHeader = PdfColor.fromInt(0xFF5C6BC0);
    final PdfColor salesRowOdd = PdfColor.fromInt(0xFFE8EAF6);
    final PdfColor salesTotalRow = PdfColor.fromInt(0xFFC5CAE9);
    final PdfColor salesGrandColor = PdfColor.fromInt(0xFF283593);
    final PdfColor summaryHeader = PdfColor.fromInt(0xFFFFA726);
    final PdfColor summaryRowOdd = PdfColor.fromInt(0xFFFFF3E0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  pw.Center(
                      child: pw.Text('فاتورة المورد ${widget.supplierName}',
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 5),
                  pw.Center(
                      child: pw.Text(
                          'بتاريخ ${widget.selectedDate}'
                          '${invoice.sValue.isNotEmpty ? '  -  س: ${invoice.sValue}' : ''}',
                          style: const pw.TextStyle(
                              fontSize: 14, color: PdfColors.grey700))),
                  pw.SizedBox(height: 15),

                  // جدول المبيعات المجمّع
                  if (invoice.groupedSales.isNotEmpty) ...[
                    _buildPdfSectionTitle('المبيعات المجمّعة', salesGrandColor),
                    pw.Table(
                      border:
                          pw.TableBorder.all(color: borderColor, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                        4: const pw.FlexColumnWidth(2),
                        5: const pw.FlexColumnWidth(4),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: salesHeader),
                          children: [
                            _buildPdfHeaderCell('الإجمالي', headerTextColor),
                            _buildPdfHeaderCell('السعر', headerTextColor),
                            _buildPdfHeaderCell('الصافي', headerTextColor),
                            _buildPdfHeaderCell('القائم', headerTextColor),
                            _buildPdfHeaderCell('العدد', headerTextColor),
                            _buildPdfHeaderCell('المادة', headerTextColor),
                          ],
                        ),
                        ...invoice.groupedSales.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          final color =
                              index % 2 == 0 ? rowEvenColor : salesRowOdd;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: color),
                            children: [
                              _buildPdfCell(line.totalValue.toStringAsFixed(2),
                                  textColor: salesGrandColor, isBold: true),
                              _buildPdfCell(line.price),
                              _buildPdfCell(line.totalNet.toStringAsFixed(2)),
                              _buildPdfCell(
                                  line.totalStanding.toStringAsFixed(2)),
                              _buildPdfCell(line.totalCount.toStringAsFixed(0)),
                              _buildPdfCell(line.material),
                            ],
                          );
                        }).toList(),
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: salesTotalRow),
                          children: [
                            _buildPdfCell(salesTotalValue.toStringAsFixed(2),
                                textColor: salesGrandColor, isBold: true),
                            _buildPdfCell(''),
                            _buildPdfCell(salesTotalNet.toStringAsFixed(2),
                                isBold: true),
                            _buildPdfCell(salesTotalStanding.toStringAsFixed(2),
                                isBold: true),
                            _buildPdfCell(salesTotalCount.toStringAsFixed(0),
                                isBold: true),
                            _buildPdfCell('المجموع', isBold: true),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],

                  // جدول المقارنة (مستلم مقابل مباع)
                  if (invoice.comparison.isNotEmpty) ...[
                    _buildPdfSectionTitle(
                        'الاستلام - المبيعات', PdfColor.fromInt(0xFFEF6C00)),
                    pw.Table(
                      border:
                          pw.TableBorder.all(color: borderColor, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(4),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: summaryHeader),
                          children: [
                            _buildPdfHeaderCell('البايت', PdfColors.black),
                            _buildPdfHeaderCell(
                                'صادر (مبيعات)', PdfColors.black),
                            _buildPdfHeaderCell(
                                'وارد (استلام)', PdfColors.black),
                            _buildPdfHeaderCell('المادة', PdfColors.black),
                          ],
                        ),
                        ...invoice.comparison.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final color =
                              index % 2 == 0 ? rowEvenColor : summaryRowOdd;
                          final balanceColor = item.difference >= 0
                              ? PdfColor.fromInt(0xFF2E7D32)
                              : PdfColor.fromInt(0xFFC62828);
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: color),
                            children: [
                              _buildPdfCell(item.difference.toStringAsFixed(0),
                                  textColor: balanceColor, isBold: true),
                              _buildPdfCell(item.salesCount.toStringAsFixed(0)),
                              _buildPdfCell(
                                  item.receiptCount.toStringAsFixed(0)),
                              _buildPdfCell(item.material),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],

                  // لوحة المصاريف والخلاصة
                  _buildPdfSectionTitle(
                      'المصاريف والصافي', PdfColor.fromInt(0xFF455A64)),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(3),
                    },
                    children: [
                      _buildPdfSummaryRow('إجمالي المبيعات',
                          invoice.totalSalesValue.toStringAsFixed(2)),
                      _buildPdfSummaryRow(
                          'المعلوم (${invoice.maloomPercent.toStringAsFixed(2)}%)',
                          invoice.maloomValue.toStringAsFixed(2)),
                      _buildPdfSummaryRow(
                          'الدفعة', invoice.paymentValue.toStringAsFixed(2)),
                      _buildPdfSummaryRow(
                          'الحمولة', invoice.loadValue.toStringAsFixed(2)),
                      _buildPdfSummaryRow(
                          'العتالة', invoice.portageValue.toStringAsFixed(2)),
                      _buildPdfSummaryRow('إجمالي المصاريف',
                          invoice.totalExpenses.toStringAsFixed(2),
                          isBold: true),
                      _buildPdfSummaryRow('صافي الفاتورة',
                          invoice.netInvoice.toStringAsFixed(2),
                          isBold: true,
                          valueColor: PdfColor.fromInt(0xFF1B5E20)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // --- دوال مساعدة للـ PDF ---
  pw.Widget _buildPdfSectionTitle(String title, PdfColor bgColor) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      margin: const pw.EdgeInsets.only(bottom: 5),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Center(
        child: pw.Text(
          title,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }

  pw.Widget _buildPdfHeaderCell(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, color: color, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text,
      {PdfColor textColor = PdfColors.black, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.TableRow _buildPdfSummaryRow(String label, String value,
      {bool isBold = false, PdfColor valueColor = PdfColors.black}) {
    return pw.TableRow(
      children: [
        _buildPdfCell(value, textColor: valueColor, isBold: isBold),
        _buildPdfCell(label, isBold: isBold),
      ],
    );
  }

  // --- دوال بناء الواجهة UI (تبقى كما هي) ---
  Widget _buildHeaderCell(String text, int flex, {Color color = Colors.white}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, int flex,
      {Color color = Colors.black87,
      FontWeight fontWeight = FontWeight.normal}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: fontWeight,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(top: 16, bottom: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  // حقل إدخال رقمي بنمط موحّد للوحة المصاريف
  Widget _buildExpenseField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              onChanged: (_) => _recalculate(),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // صف ملخص (قراءة فقط) في الخلاصة النهائية
  Widget _buildSummaryRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'فاتورة المورد ${widget.supplierName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leadingWidth: 100,
        leading: ExitButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          width: 80,
          height: 40,
          text: 'خروج',
        ),
        actions: [
          PdfActionMenu(
            type: 'supplier',
            supplierOrCustomerName: widget.supplierName,
            filterDesc: widget.selectedDate,
            balance: _supplierBalance,
            storeName: widget.storeName,
            selectedDate: widget.selectedDate,
            iconSize: 60,
            getItems: () async {
              final data = await _invoiceFuture;
              return [data];
            },
            generatePdfCallback: (items) async {
              final data = items[0] as SupplierInvoice;
              return _generatePdfBytes(data);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'بتاريخ ${widget.selectedDate}'
              '${widget.sValue.isNotEmpty ? '  -  س: ${widget.sValue}' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<SupplierInvoice>(
          future: _invoiceFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('لا توجد بيانات'));
            }

            final invoice = snapshot.data!;
            final bool hasSales = invoice.groupedSales.isNotEmpty;
            final bool hasComparison = invoice.comparison.isNotEmpty;

            if (!hasSales && !hasComparison) {
              return const Center(
                child: Text(
                  'لا توجد حركات لهذا المورد وفق الشرط المحدد',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            // مجاميع جدول المبيعات المجمّع
            double salesTotalCount = 0;
            double salesTotalStanding = 0;
            double salesTotalNet = 0;
            double salesTotalValue = 0;
            if (hasSales) {
              for (var line in invoice.groupedSales) {
                salesTotalCount += line.totalCount;
                salesTotalStanding += line.totalStanding;
                salesTotalNet += line.totalNet;
                salesTotalValue += line.totalValue;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // --- جدول المبيعات المجمّع ---
                  if (hasSales) ...[
                    _buildSectionTitle('المبيعات المجمّعة', Colors.indigo),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: Colors.indigo.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                _buildHeaderCell('المادة', 4),
                                _buildHeaderCell('العدد', 2),
                                _buildHeaderCell('القائم', 2),
                                _buildHeaderCell('الصافي', 2),
                                _buildHeaderCell('السعر', 2),
                                _buildHeaderCell('الإجمالي', 3),
                              ],
                            ),
                          ),
                          ...invoice.groupedSales.map((line) => Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.shade300)),
                                ),
                                child: Row(
                                  children: [
                                    _buildDataCell(line.material, 4),
                                    _buildDataCell(
                                        line.totalCount.toStringAsFixed(0), 2),
                                    _buildDataCell(
                                        line.totalStanding.toStringAsFixed(2),
                                        2),
                                    _buildDataCell(
                                        line.totalNet.toStringAsFixed(2), 2),
                                    _buildDataCell(line.price, 2),
                                    _buildDataCell(
                                        line.totalValue.toStringAsFixed(2), 3,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo),
                                  ],
                                ),
                              )),
                          // سطر المجموع
                          Container(
                            color: Colors.indigo.shade100,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                _buildDataCell('المجموع', 4,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell(
                                    salesTotalCount.toStringAsFixed(0), 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell(
                                    salesTotalStanding.toStringAsFixed(2), 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell(
                                    salesTotalNet.toStringAsFixed(2), 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell('', 2),
                                _buildDataCell(
                                    salesTotalValue.toStringAsFixed(2), 3,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // --- جدول المقارنة ---
                  if (hasComparison) ...[
                    _buildSectionTitle(
                        'الاستلام - المبيعات', Colors.orange[800]!),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: Colors.orange.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                _buildHeaderCell('المادة', 4,
                                    color: Colors.black87),
                                _buildHeaderCell('وارد (استلام)', 2,
                                    color: Colors.black87),
                                _buildHeaderCell('صادر (مبيعات)', 2,
                                    color: Colors.black87),
                                _buildHeaderCell('البايت', 2,
                                    color: Colors.black87),
                              ],
                            ),
                          ),
                          ...invoice.comparison.map((item) => Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.shade300)),
                                ),
                                child: Row(
                                  children: [
                                    _buildDataCell(item.material, 4),
                                    _buildDataCell(
                                        item.receiptCount.toStringAsFixed(0),
                                        2),
                                    _buildDataCell(
                                        item.salesCount.toStringAsFixed(0), 2),
                                    _buildDataCell(
                                      item.difference.toStringAsFixed(0),
                                      2,
                                      fontWeight: FontWeight.bold,
                                      color: item.difference >= 0
                                          ? Colors.green[800]!
                                          : Colors.red[800]!,
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // --- لوحة المصاريف ---
                  _buildSectionTitle('المصاريف', Colors.blueGrey[700]!),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        _buildExpenseField(
                          label: 'المعلوم (نسبة %)',
                          controller: _maloomPercentController,
                        ),
                        // قيمة المعلوم المحسوبة (قراءة فقط)
                        _buildSummaryRow(
                          'قيمة المعلوم',
                          invoice.maloomValue.toStringAsFixed(2),
                        ),
                        const Divider(),
                        _buildExpenseField(
                          label: 'الدفعة',
                          controller: _paymentController,
                        ),
                        _buildExpenseField(
                          label: 'الحمولة',
                          controller: _loadController,
                        ),
                        _buildExpenseField(
                          label: 'العتالة',
                          controller: _portageController,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _savingPortage ? null : _savePortageToBox,
                            icon: _savingPortage
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('تسجيل العتالة في الصندوق'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- الخلاصة النهائية ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(top: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      border: Border.all(color: Colors.teal.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('إجمالي المبيعات',
                            invoice.totalSalesValue.toStringAsFixed(2)),
                        _buildSummaryRow('إجمالي المصاريف',
                            invoice.totalExpenses.toStringAsFixed(2)),
                        const Divider(thickness: 1.5),
                        _buildSummaryRow(
                          'صافي الفاتورة',
                          invoice.netInvoice.toStringAsFixed(2),
                          isBold: true,
                          valueColor: Colors.teal[900],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
