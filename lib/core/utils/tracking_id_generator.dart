import 'dart:math';

class TrackingIdGenerator {
  static String generate() {
    final year = DateTime.now().year;
    // Epoch timestamp کا آخری حصہ اور 3 ہندسوں کا رینڈم نمبر
    final timeMillis = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final randomDigits = Random().nextInt(900) + 100;

    return 'AG-$year-$timeMillis$randomDigits'; // Example: AG-2026-894123
  }
}