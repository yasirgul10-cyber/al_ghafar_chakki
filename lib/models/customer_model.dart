// lib/models/customer_model.dart

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double balance; // مثبت (+) = ادھار لینا ہے، منفی (-) = جمع / دینا ہے

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.balance,
  });

  /// 1. Firestore میں ڈیٹا محفوظ کرتے وقت (Object to Map)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'balance': balance,
    };
  }

  /// 2. Firestore سے ڈیٹا حاصل کرتے وقت (Map to Object)
  factory CustomerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CustomerModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 3. اسٹیٹ اپڈیٹ یا ترمیم کی سہولت کے لیے (Immutable Copy)
  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? balance,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
    );
  }
}