import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String trackingId;
  final String customerName;
  final String phone;
  final String category;
  final double quantity;
  final String unit;
  final double ratePerKg;
  final double totalAmount;
  final String paymentStatus;
  final double paidAmount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.trackingId,
    required this.customerName,
    required this.phone,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.ratePerKg,
    required this.totalAmount,
    required this.paymentStatus,
    this.paidAmount = 0.0,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // ⚖️ Unit Conversions & Financial Calculations
  double get quantityInKg {
    switch (unit) {
      case 'Gram':
        return quantity / 1000.0;
      case 'Mann (40 KG)':
        return quantity * 40.0;
      case 'KG':
      default:
        return quantity;
    }
  }

  double get calculatedTotal => quantityInKg * ratePerKg;

  // 🛡️ Safe Remaining Amount (Negative Guard)
  double get remainingAmount {
    final remaining = totalAmount - paidAmount;
    return remaining < 0 ? 0.0 : remaining;
  }

  Map<String, dynamic> toMap() {
    return {
      'trackingId': trackingId,
      'customerName': customerName,
      'phone': phone,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'ratePerKg': ratePerKg,
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    return OrderModel(
      id: docId,
      trackingId: map['trackingId'] ?? '',
      customerName: map['customerName'] ?? '',
      phone: map['phone'] ?? '',
      category: map['category'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? 'KG',
      ratePerKg: (map['ratePerKg'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['paymentStatus'] ?? 'Unpaid',
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Order Received',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}