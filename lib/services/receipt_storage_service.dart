import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/receipt_model.dart';
import 'package:flutter/foundation.dart';

class ReceiptStorageService {
  Future<String> _getBasePath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isWindows) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final rootPath = '${directory!.path}/alhalmarket';
    final rootFolder = Directory(rootPath);
    if (!await rootFolder.exists()) {
      await rootFolder.create(recursive: true);
    }
    return rootPath;
  }

  String _createFileName(String date) {
    final dateParts = date.split('/');
    final formattedDate = dateParts.join('-');
    return 'receipt-$formattedDate.json';
  }

  // دالة مساعدة لتحويل ReceiptDocument إلى Map يدوياً
  Map<String, dynamic> _documentToJson(ReceiptDocument doc) {
    return {
      'recordNumber': doc.recordNumber,
      'date': doc.date,
      'sellerName': doc.sellerName,
      'storeName': doc.storeName,
      'dayName': doc.dayName,
      'receipts': doc.receipts.map((r) => r.toJson()).toList(),
      'totals': doc.totals,
    };
  }

  Future<bool> saveReceiptDocument(ReceiptDocument document) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/ReceiptJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) await folder.create(recursive: true);

      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);

      String finalRecordNumber;
      if (document.recordNumber.isNotEmpty && document.recordNumber != '1') {
        finalRecordNumber = document.recordNumber;
      } else {
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
          final existingDoc = ReceiptDocument.fromJson(jsonMap);
          finalRecordNumber = existingDoc.recordNumber;
        } else {
          finalRecordNumber = await getNextJournalNumber();
        }
      }

      double totalCount = 0, totalStanding = 0, totalPayment = 0, totalLoad = 0;
      for (var receipt in document.receipts) {
        totalCount += double.tryParse(receipt.count) ?? 0;
        totalStanding += double.tryParse(receipt.standing) ?? 0;
        totalPayment += double.tryParse(receipt.payment) ?? 0;
        totalLoad += double.tryParse(receipt.load) ?? 0;
      }

      final documentToSave = ReceiptDocument(
        recordNumber: finalRecordNumber,
        date: document.date,
        sellerName: document.sellerName,
        storeName: document.storeName,
        dayName: document.dayName,
        receipts: document.receipts,
        totals: {
          'totalCount': totalCount.toStringAsFixed(0),
          'totalStanding': totalStanding.toStringAsFixed(2),
          'totalPayment': totalPayment.toStringAsFixed(2),
          'totalLoad': totalLoad.toStringAsFixed(2),
        },
      );

      // استخدام الدالة المساعدة بدلاً من toJson مباشرة
      final jsonString = jsonEncode(_documentToJson(documentToSave));
      await file.writeAsString(jsonString);
      if (kDebugMode) debugPrint('✅ تم استبدال ملف الاستلام بنجاح: $filePath');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ ملف الاستلام: $e');
      return false;
    }
  }

  // باقي الدوال كما هي ...
  Future<ReceiptDocument?> loadReceiptDocumentForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/ReceiptJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return ReceiptDocument.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة يومية الاستلام: $e');
      return null;
    }
  }

  Future<ReceiptDocument?> loadReceiptDocument(
      String date, String recordNumber) async {
    return await loadReceiptDocumentForDate(date);
  }

  Future<List<String>> getAvailableRecords(String date) async {
    try {
      final document = await loadReceiptDocumentForDate(date);
      if (document != null) return [document.recordNumber];
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة سجلات الاستلام: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getAvailableDatesWithNumbers() async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/ReceiptJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) return [];

      final files = await folder.list().toList();
      final datesWithNumbers = <Map<String, String>>[];

      for (var file in files) {
        if (file is File &&
            file.path.endsWith('.json') &&
            file.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('receipt-')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final date = jsonMap['date']?.toString() ?? '';
            final journalNumber = jsonMap['recordNumber']?.toString() ?? '1';
            if (date.isNotEmpty) {
              datesWithNumbers
                  .add({'date': date, 'journalNumber': journalNumber});
            }
          } catch (e) {}
        }
      }

      datesWithNumbers.sort((a, b) {
        final numA = int.tryParse(a['journalNumber'] ?? '0') ?? 0;
        final numB = int.tryParse(b['journalNumber'] ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      return datesWithNumbers;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة تواريخ الاستلام: $e');
      return [];
    }
  }

  Future<String?> getFilePath(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/ReceiptJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);
      if (await file.exists()) return filePath;
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في الحصول على مسار ملف الاستلام: $e');
      return null;
    }
  }

  Future<String> getJournalNumberForDate(String date) async {
    try {
      final document = await loadReceiptDocumentForDate(date);
      return document?.recordNumber ?? '1';
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في الحصول على رقم يومية الاستلام: $e');
      return '1';
    }
  }

  Future<String> getNextJournalNumber() async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/ReceiptJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) return '1';

      final files = await folder.list().toList();
      int maxJournalNumber = 0;
      for (var file in files) {
        if (file is File &&
            file.path.endsWith('.json') &&
            file.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('receipt-')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final journalNumber =
                int.tryParse(jsonMap['recordNumber'] ?? '0') ?? 0;
            if (journalNumber > maxJournalNumber)
              maxJournalNumber = journalNumber;
          } catch (e) {}
        }
      }
      return (maxJournalNumber + 1).toString();
    } catch (e) {
      if (kDebugMode)
        debugPrint('❌ خطأ في الحصول على الرقم التسلسلي التالي للاستلام: $e');
      return '1';
    }
  }
}
