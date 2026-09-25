class AppStrings {
  static const String appName = 'Al Ghaffar Chakki';
  static const String appTagline = 'Flour & Spices Order Tracking';

  // Categories
  static const String categoryWheat = 'آٹا پسائی (Wheat Grinding)';
  static const String categorySpices = 'مصالحہ پسائی (Spices Grinding)';

  // Weight Units
  static const String unitKg = 'KG';
  static const String unitGram = 'Gram';
  static const String unitMann = 'Mann (40 KG)';

  // Payment Status
  static const String paymentPaid = 'Paid';
  static const String paymentUnpaid = 'Unpaid';
  static const String paymentPartial = 'Partial';

  // Order Statuses
  static const List<String> orderStatuses = [
    'Order Received',
    'In Queue',
    'Grinding',
    'Quality Check',
    'Ready for Pickup',
    'Delivered',
  ];
}