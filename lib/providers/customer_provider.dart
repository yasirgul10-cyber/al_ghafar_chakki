import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/customer_model.dart';

class CustomerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _customersSubscription;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Firestore Collection Reference
  CollectionReference<Map<String, dynamic>> get _customerCollection =>
      _firestore.collection('customers');

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

  /// 🔄 1. تمام کسٹمرز کا ریئل ٹائم اسٹریم (نام کے لحاظ سے ترتیب وار)
  void fetchCustomers() {
    _customersSubscription?.cancel();

    _setLoading(true);
    _errorMessage = null;

    _customersSubscription = _customerCollection
        .orderBy('name')
        .snapshots()
        .listen(
      (snapshot) {
        _customers = snapshot.docs.map((doc) {
          return CustomerModel.fromMap(
            doc.data(),
            doc.id,
          );
        }).toList();

        _setLoading(false);
        _errorMessage = null;
      },
      onError: (error) {
        _setLoading(false);
        _errorMessage = 'کسٹمرز کا ڈیٹا لوڈ کرنے میں ناکامی: $error';
        notifyListeners();
      },
    );
  }

  /// ➕ 2. نیا کسٹمر شامل کریں (ڈپلیکیٹ فون نمبر چیک کے ساتھ)
  Future<bool> addCustomer(CustomerModel customer) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (customer.name.trim().isEmpty) {
        throw Exception('کسٹمر کا نام درج کرنا ضروری ہے۔');
      }

      if (customer.phone.trim().isEmpty) {
        throw Exception('کسٹمر کا فون نمبر درج کرنا ضروری ہے۔');
      }

      final normalizedPhone = formatPakistanPhone(customer.phone);

      // چیک کریں کہ یہ نمبر پہلے سے موجود تو نہیں
      final existingCustomer = await _customerCollection
          .where(
            'phone',
            isEqualTo: normalizedPhone,
          )
          .limit(1)
          .get();

      if (existingCustomer.docs.isNotEmpty) {
        throw Exception('یہ فون نمبر پہلے سے رجسٹرڈ ہے۔');
      }

      final customerRef = _customerCollection.doc();

      await customerRef.set({
        'name': customer.name.trim(),
        'phone': normalizedPhone,
        'address': customer.address.trim(),
        'balance': customer.balance,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('کسٹمر شامل کرنے میں ناکامی: $e');
      _setLoading(false);
      return false;
    }
  }

  /// ✏️ 3. کسٹمر کی تفصیلات اپڈیٹ کریں
  Future<bool> updateCustomer(CustomerModel customer) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (customer.id.trim().isEmpty) {
        throw Exception('کسٹمر ID غائب ہے۔');
      }

      if (customer.name.trim().isEmpty) {
        throw Exception('کسٹمر کا نام درج کرنا ضروری ہے۔');
      }

      if (customer.phone.trim().isEmpty) {
        throw Exception('کسٹمر کا فون نمبر درج کرنا ضروری ہے۔');
      }

      final normalizedPhone = formatPakistanPhone(customer.phone);

      // چیک کریں کہ یہ فون نمبر کسی دوسرے کسٹمر کے پاس تو نہیں
      final existingCustomer = await _customerCollection
          .where(
            'phone',
            isEqualTo: normalizedPhone,
          )
          .limit(2)
          .get();

      final duplicateExists = existingCustomer.docs.any(
        (doc) => doc.id != customer.id,
      );

      if (duplicateExists) {
        throw Exception('یہ فون نمبر کسی دوسرے کسٹمر کے نام پر پہلے سے رجسٹرڈ ہے۔');
      }

      await _customerCollection.doc(customer.id).update({
        'name': customer.name.trim(),
        'phone': normalizedPhone,
        'address': customer.address.trim(),
        'balance': customer.balance,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('کسٹمر اپڈیٹ کرنے میں ناکامی: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 🗑️ 4. کسٹمر کو ڈیلیٹ کریں
  Future<bool> deleteCustomer(String customerId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (customerId.trim().isEmpty) {
        throw Exception('کسٹمر ID غائب ہے۔');
      }

      await _customerCollection.doc(customerId).delete();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('کسٹمر ڈیلیٹ کرنے میں ناکامی: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 💰 5. کسٹمر کا بیلنس اپڈیٹ کریں (آرڈر یا وصولی پر)
  /// مثبت رقم (+) = ادھار میں اضافہ
  /// منفی رقم (-) = نقد وصولی / بیلنس میں کمی
  Future<bool> updateCustomerBalance(
    String customerId,
    double amountChange,
  ) async {
    try {
      if (customerId.trim().isEmpty) {
        throw Exception('کسٹمر ID غائب ہے۔');
      }

      await _customerCollection.doc(customerId).update({
        'balance': FieldValue.increment(amountChange),
      });

      return true;
    } catch (e) {
      _setError('کسٹمر کا بیلنس اپڈیٹ کرنے میں ناکامی: $e');
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

  @override
  void dispose() {
    _customersSubscription?.cancel();
    super.dispose();
  }
}