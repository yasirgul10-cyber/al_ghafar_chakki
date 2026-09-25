import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/tracking_id_generator.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 📞 نمبر کو تمام جگہوں کے لیے یکساں (Standard Format) کرنے کا فنکشن
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
      final docQuery = await _firestore
          .collection('orders')
          .where('trackingId', isEqualTo: candidateId)
          .limit(1)
          .get();

      if (docQuery.docs.isEmpty) {
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

  // 📝 Create Order with Automatic Ledger Entry Integration
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
      final trackingId = await _generateUniqueTrackingId();

      final quantityInKg = switch (unit) {
        AppStrings.unitGram => quantity / 1000.0,
        AppStrings.unitMann => quantity * 40.0,
        _ => quantity,
      };

      final totalAmount = quantityInKg * ratePerKg;

      final paymentStatus = paidAmount <= 0
          ? AppStrings.paymentUnpaid
          : paidAmount >= totalAmount
              ? AppStrings.paymentPaid
              : AppStrings.paymentPartial;

      final docRef = _firestore.collection('orders').doc();
      final now = DateTime.now();

      final order = OrderModel(
        id: docRef.id,
        trackingId: trackingId,
        customerName: customerName,
        phone: phone,
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

      // 1️⃣ آرڈر کو فائر اسٹور میں محفوظ کریں
      await docRef.set(order.toMap());

      // 2️⃣ کھاتے (Ledger Transactions) میں خودکار اندراج
      final formattedPhone = _formatPakistanPhone(phone);
      final ledgerCollection = _firestore.collection('ledger_transactions');

      // 🅰️ ادھار اندراج (Debit Entry): آرڈر کا کل بل
      await ledgerCollection.add({
        'customerName': customerName,
        'customerPhone': formattedPhone,
        'description': 'آرڈر #$trackingId کا بل ($category)',
        'amount': totalAmount,
        'isCredit': false, // false = ادھار (Debit)
        'date': Timestamp.fromDate(now),
      });

      // 🅱️ وصولی اندراج (Credit Entry): اگر کسٹمر نے موقع پر کچھ رقم ادا کی ہے
      if (paidAmount > 0) {
        await ledgerCollection.add({
          'customerName': customerName,
          'customerPhone': formattedPhone,
          'description': 'آرڈر #$trackingId کی نقد وصولی',
          'amount': paidAmount,
          'isCredit': true, // true = وصولی (Credit)
          'date': Timestamp.fromDate(now),
        });
      }

      _setLoading(false);
      return order;
    } catch (e) {
      _setError('Failed to create order: $e');
      _setLoading(false);
      return null;
    }
  }

  // 🔍 Real-Time Tracking Stream
  Stream<OrderModel?> trackOrderByTrackingId(String trackingId) {
    return _firestore
        .collection('orders')
        .where('trackingId', isEqualTo: trackingId.trim().toUpperCase())
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
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 🔄 Update Status with Validation
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    if (!AppStrings.orderStatuses.contains(newStatus)) {
      _setError('Invalid status: $newStatus');
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
      _setError('Failed to update status: $e');
      return false;
    }
  }

  // 💵 Update Payment Details + Record Additional Payment in Ledger
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
      final paymentStatus = newPaidAmount <= 0
          ? AppStrings.paymentUnpaid
          : newPaidAmount >= totalAmount
              ? AppStrings.paymentPaid
              : AppStrings.paymentPartial;

      await _firestore.collection('orders').doc(orderId).update({
        'paidAmount': newPaidAmount,
        'paymentStatus': paymentStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // اگر بقایا رقم میں سے مزید وصولی ہوئی ہے تو اس کا بھی لیجر میں اندراج کریں
      if (addedPayment != null &&
          addedPayment > 0 &&
          customerName != null &&
          customerPhone != null) {
        final formattedPhone = _formatPakistanPhone(customerPhone);
        await _firestore.collection('ledger_transactions').add({
          'customerName': customerName,
          'customerPhone': formattedPhone,
          'description': trackingId != null
              ? 'آرڈر #$trackingId کی بقایا وصولی'
              : 'آرڈر کی بقایا وصولی',
          'amount': addedPayment,
          'isCredit': true,
          'date': Timestamp.fromDate(DateTime.now()),
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update payment: $e');
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}