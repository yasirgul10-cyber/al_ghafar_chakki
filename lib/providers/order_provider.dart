import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/tracking_id_generator.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 📞 فون نمبر کو تمام جگہوں کے لیے یکساں (Standard Format) کرنے کا فنکشن
  String _formatPakistanPhone(String phone) {
    var value = phone.trim().replaceAll(RegExp(r'[\s-]'), '');

    if (value.startsWith('+92')) {
      value = value.substring(1);
    } else if (value.startsWith('0')) {
      value = '92${value.substring(1)}';
    }

    return value;
  }

  // 🔒 Firestore Uniqueness Check for Tracking ID
  Future<String> _generateUniqueTrackingId() async {
    String candidateId = '';
    bool isUnique = false;
    int attempts = 0;

    while (!isUnique && attempts < 10) {
      candidateId = TrackingIdGenerator.generate();

      final query = await _firestore
          .collection('orders')
          .where('trackingId', isEqualTo: candidateId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        isUnique = true;
      } else {
        attempts++;
      }
    }

    if (!isUnique) {
      candidateId =
          'AG-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch}';
    }

    return candidateId;
  }

  // 👤 کسٹمر تلاش کریں یا نیا کسٹمر فائر اسٹور میں بنائیں
  Future<DocumentReference<Map<String, dynamic>>> _findOrCreateCustomer({
    required String customerName,
    required String phone,
  }) async {
    final normalizedPhone = _formatPakistanPhone(phone);

    final query = await _firestore
        .collection('customers')
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.reference;
    }

    final customerRef = _firestore.collection('customers').doc();

    await customerRef.set({
      'name': customerName,
      'phone': normalizedPhone,
      'address': '',
      'balance': 0.0,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    return customerRef;
  }

  // 📝 Create Order with Atomic Write Batch & Customer Ledger Sync
  Future<OrderModel?> createOrder({
    required String customerName,
    required String phone,
    required String category,
    required double quantity,
    required String unit,
    required double ratePerKg,
    required double paidAmount,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 🛑 ویلیڈیشنز (Validations)
      if (customerName.trim().isEmpty) {
        throw Exception('کسٹمر کا نام درج کرنا ضروری ہے۔');
      }

      if (phone.trim().isEmpty) {
        throw Exception('کسٹمر کا فون نمبر درج کرنا ضروری ہے۔');
      }

      if (quantity <= 0) {
        throw Exception('مقدار 0 سے زیادہ ہونی چاہیے۔');
      }

      if (ratePerKg < 0) {
        throw Exception('ریٹ منفی نہیں ہو سکتا۔');
      }

      if (paidAmount < 0) {
        throw Exception('ادا شدہ رقم منفی نہیں ہو سکتی۔');
      }

      // ⚖️ یونٹس کے مطابق KG میں کنورژن
      final quantityInKg = switch (unit) {
        AppStrings.unitGram => quantity / 1000.0,
        AppStrings.unitMann => quantity * 40.0,
        _ => quantity,
      };

      final totalAmount = quantityInKg * ratePerKg;

      if (paidAmount > totalAmount) {
        throw Exception('ادا شدہ رقم کل بل سے زیادہ نہیں ہو سکتی۔');
      }

      final paymentStatus = paidAmount <= 0
          ? AppStrings.paymentUnpaid
          : paidAmount >= totalAmount
              ? AppStrings.paymentPaid
              : AppStrings.paymentPartial;

      final trackingId = await _generateUniqueTrackingId();
      final now = DateTime.now();
      final orderRef = _firestore.collection('orders').doc();
      final normalizedPhone = _formatPakistanPhone(phone);

      final order = OrderModel(
        id: orderRef.id,
        trackingId: trackingId,
        customerName: customerName.trim(),
        phone: normalizedPhone,
        category: category,
        quantity: quantity,
        unit: unit,
        ratePerKg: ratePerKg,
        totalAmount: totalAmount,
        paymentStatus: paymentStatus,
        paidAmount: paidAmount,
        status: AppStrings.orderStatuses.first,
        createdAt: now,
        updatedAt: now,
      );

      // 👤 کسٹمر ریفرنس حاصل کریں
      final customerRef = await _findOrCreateCustomer(
        customerName: customerName.trim(),
        phone: normalizedPhone,
      );

      // 🔄 WriteBatch شروع کریں (تمام آپریشنز ایک ساتھ ہوں گے)
      final batch = _firestore.batch();

      // 1️⃣ آرڈر محفوظ کریں
      batch.set(orderRef, order.toMap());

      // 2️⃣ ادھار اندراج (Debit Entry): کل بل کھاتے میں ڈالیں
      final debitRef = _firestore.collection('ledger_transactions').doc();
      batch.set(debitRef, {
        'customerName': customerName.trim(),
        'customerPhone': normalizedPhone,
        'description': 'آرڈر #$trackingId کا بل ($category)',
        'amount': totalAmount,
        'isCredit': false, // false = ادھار (Debit)
        'date': Timestamp.fromDate(now),
      });

      // 3️⃣ وصولی اندراج (Credit Entry): اگر موقع پر کچھ رقم ادا ہوئی ہے
      if (paidAmount > 0) {
        final creditRef = _firestore.collection('ledger_transactions').doc();
        batch.set(creditRef, {
          'customerName': customerName.trim(),
          'customerPhone': normalizedPhone,
          'description': 'آرڈر #$trackingId کی نقد وصولی',
          'amount': paidAmount,
          'isCredit': true, // true = وصولی (Credit)
          'date': Timestamp.fromDate(now),
        });
      }

      // 4️⃣ کسٹمر کے کل بقایا بیلنس کو اپڈیٹ کریں
      final balanceChange = totalAmount - paidAmount;
      if (balanceChange != 0) {
        batch.update(customerRef, {
          'balance': FieldValue.increment(balanceChange),
        });
      }

      // 🚀 تمام تبدیلیاں ایک ساتھ فائر اسٹور میں سیو کریں
      await batch.commit();

      _setLoading(false);
      return order;
    } catch (e) {
      _setError('آرڈر بنانے میں ناکامی: $e');
      _setLoading(false);
      return null;
    }
  }

  // 🔍 Real-Time Tracking Stream
  Stream<OrderModel?> trackOrderByTrackingId(String trackingId) {
    return _firestore
        .collection('orders')
        .where(
          'trackingId',
          isEqualTo: trackingId.trim().toUpperCase(),
        )
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return OrderModel.fromMap(doc.data(), doc.id);
      }
      return null;
    });
  }

  // 📊 All Orders Stream (Admin Dashboard)
  Stream<List<OrderModel>> getAllOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => OrderModel.fromMap(
              doc.data(),
              doc.id,
            ),
          )
          .toList();
    });
  }

  // 🔄 Update Status with Validation
  Future<bool> updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    if (!AppStrings.orderStatuses.contains(newStatus)) {
      _setError('ناقابل قبول اسٹیٹس: $newStatus');
      return false;
    }

    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('اسٹیٹس اپڈیٹ میں ناکامی: $e');
      return false;
    }
  }

  // 💵 Update Payment Details + Atomic Ledger Integration
  Future<bool> updatePaymentDetails({
    required String orderId,
    required double newPaidAmount,
    required double totalAmount,
    String? customerName,
    String? customerPhone,
    String? trackingId,
    double? addedPayment,
  }) async {
    try {
      if (newPaidAmount < 0) {
        _setError('ادا شدہ رقم منفی نہیں ہو سکتی۔');
        return false;
      }

      if (newPaidAmount > totalAmount) {
        _setError('ادا شدہ رقم کل بل سے زیادہ نہیں ہو سکتی۔');
        return false;
      }

      final paymentStatus = newPaidAmount <= 0
          ? AppStrings.paymentUnpaid
          : newPaidAmount >= totalAmount
              ? AppStrings.paymentPaid
              : AppStrings.paymentPartial;

      final orderRef = _firestore.collection('orders').doc(orderId);
      final batch = _firestore.batch();
      final now = DateTime.now();

      // 1️⃣ آرڈر کی رقم اپڈیٹ کریں
      batch.update(orderRef, {
        'paidAmount': newPaidAmount,
        'paymentStatus': paymentStatus,
        'updatedAt': Timestamp.fromDate(now),
      });

      // 2️⃣ اگر مزید بقایا رقم موصول ہوئی ہے تو لیجر اور کسٹمر بیلنس اپڈیٹ کریں
      if (addedPayment != null &&
          addedPayment > 0 &&
          customerName != null &&
          customerPhone != null) {
        final normalizedPhone = _formatPakistanPhone(customerPhone);

        final paymentRef = _firestore.collection('ledger_transactions').doc();
        batch.set(paymentRef, {
          'customerName': customerName,
          'customerPhone': normalizedPhone,
          'description': trackingId != null
              ? 'آرڈر #$trackingId کی بقایا وصولی'
              : 'آرڈر کی بقایا وصولی',
          'amount': addedPayment,
          'isCredit': true,
          'date': Timestamp.fromDate(now),
        });

        // کسٹمر کا بیلنس کم (کمی/Minus) کریں
        final customerQuery = await _firestore
            .collection('customers')
            .where(
              'phone',
              isEqualTo: normalizedPhone,
            )
            .limit(1)
            .get();

        if (customerQuery.docs.isNotEmpty) {
          batch.update(
            customerQuery.docs.first.reference,
            {
              'balance': FieldValue.increment(-addedPayment),
            },
          );
        }
      }

      await batch.commit();

      notifyListeners();
      return true;
    } catch (e) {
      _setError('پیمنٹ اپڈیٹ میں ناکامی: $e');
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