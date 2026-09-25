import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/ledger_transaction.dart';

class LedgerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // 📞 نمبر کو تمام جگہ یکساں بنانے کا طریقہ
  String formatPakistanPhone(String phone) {
    var value = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (value.startsWith('+92')) {
      value = value.substring(1);
    } else if (value.startsWith('0')) {
      value = '92${value.substring(1)}';
    }
    return value;
  }

  // 🔄 کسٹمر کی تمام ٹرانزیکشنز کی لائیو اسٹریم
  Stream<List<LedgerTransaction>> getCustomerLedgerStream(String customerPhone) {
    final normalizedPhone = formatPakistanPhone(customerPhone);

    return _firestore
        .collection('ledger_transactions')
        .where('customerPhone', isEqualTo: normalizedPhone)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LedgerTransaction.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date)); // تازہ ترین اندراج اوپر
      return list;
    });
  }

  // ➕ نیا اندراج شامل کریں (ادھار یا وصولی)
  Future<bool> addTransaction(LedgerTransaction transaction) async {
    _isLoading = true;
    notifyListeners();

    try {
      final normalizedPhone = formatPakistanPhone(transaction.customerPhone);
      final data = transaction.toMap();
      data['customerPhone'] = normalizedPhone;

      await _firestore.collection('ledger_transactions').add(data);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}