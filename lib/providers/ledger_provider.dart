import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/ledger_transaction.dart';

class LedgerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 📞 پاکستان کے فون نمبر کو ایک یکساں فارمیٹ (92XXXXXXXXXX) میں کنورٹ کرتا ہے
  String formatPakistanPhone(String phone) {
    var value = phone.trim().replaceAll(RegExp(r'[\s-]'), '');

    if (value.startsWith('+92')) {
      value = value.substring(1);
    } else if (value.startsWith('0')) {
      value = '92${value.substring(1)}';
    }

    return value;
  }

  /// 🔄 کسٹمر کے تمام لیجر ٹرانزیکشنز کا ریئل ٹائم اسٹریم (تازہ ترین اندراج اوپر آئے گا)
  Stream<List<LedgerTransaction>> getCustomerLedgerStream(
    String customerPhone,
  ) {
    final normalizedPhone = formatPakistanPhone(customerPhone);

    return _firestore
        .collection('ledger_transactions')
        .where('customerPhone', isEqualTo: normalizedPhone)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map(
            (doc) => LedgerTransaction.fromMap(
              doc.data(),
              doc.id,
            ),
          )
          .toList();

      // تاریخ کے لحاظ سے فلٹرنگ (تازہ ترین پہلے)
      list.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      return list;
    });
  }

  /// 👤 کسٹمر کو فون نمبر کے ذریعے فائر اسٹور میں تلاش کرتا ہے
  Future<DocumentReference<Map<String, dynamic>>?> _findCustomer(
    String phone,
  ) async {
    final normalizedPhone = formatPakistanPhone(phone);

    final query = await _firestore
        .collection('customers')
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return query.docs.first.reference;
  }

  /// ➕ نیا مینوئل لیجر اندراج شامل کرتا ہے (ادھار یا وصولی)
  ///
  /// `isCredit = false`: ادھار (Customer Balance بڑھے گا)
  /// `isCredit = true`: وصولی (Customer Balance کم ہوگا)
  Future<bool> addTransaction(
    LedgerTransaction transaction,
  ) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (transaction.amount <= 0) {
        throw Exception('رقم 0 سے زیادہ ہونی چاہیے۔');
      }

      if (transaction.customerPhone.trim().isEmpty) {
        throw Exception('کسٹمر کا فون نمبر درج کرنا ضروری ہے۔');
      }

      final normalizedPhone = formatPakistanPhone(transaction.customerPhone);

      // کسٹمر کا فائر اسٹور میں وجود چیک کریں
      final customerRef = await _findCustomer(normalizedPhone);

      if (customerRef == null) {
        throw Exception('کسٹمر کا ریکارڈ نہیں ملا۔ برائے مہربانی پہلے کسٹمر شامل کریں۔');
      }

      final now = DateTime.now();
      final ledgerRef = _firestore.collection('ledger_transactions').doc();
      final batch = _firestore.batch();

      // 1️⃣ ٹرانزیکشن ریکارڈ محفوظ کریں
      batch.set(
        ledgerRef,
        {
          'customerName': transaction.customerName,
          'customerPhone': normalizedPhone,
          'description': transaction.description,
          'amount': transaction.amount,
          'isCredit': transaction.isCredit,
          'date': Timestamp.fromDate(now),
        },
      );

      // 2️⃣ کسٹمر کے کل بقایا بیلنس کو اپڈیٹ کریں
      // Debit (isCredit = false)  = +amount (ادھار میں اضافہ)
      // Credit (isCredit = true)  = -amount (وصولی پر ادھار میں کمی)
      final balanceChange = transaction.isCredit
          ? -transaction.amount
          : transaction.amount;

      batch.update(
        customerRef,
        {
          'balance': FieldValue.increment(balanceChange),
        },
      );

      // 3️⃣ تمام تبدیلیاں ایک ساتھ فائر اسٹور میں سیو کریں (Atomic Operation)
      await batch.commit();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('اندراج شامل کرنے میں ناکامی: $e');
      _setLoading(false);
      return false;
    }
  }

  // 🛠️ Helper Methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}