import 'package:cloud_firestore/cloud_firestore.dart';

class LedgerTransaction {
  final String id;
  final String customerName;
  final String customerPhone;
  final String description;
  final double amount;
  final bool isCredit; // true = وصولی (Credit), false = ادھار (Debit)
  final DateTime date;

  LedgerTransaction({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.description,
    required this.amount,
    required this.isCredit,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'description': description,
      'amount': amount,
      'isCredit': isCredit,
      'date': Timestamp.fromDate(date),
    };
  }

  factory LedgerTransaction.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    return LedgerTransaction(
      id: docId,
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      isCredit: map['isCredit'] ?? false,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}