import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';

class TrackingScreen extends StatelessWidget {
  final String trackingId;

  const TrackingScreen({
    super.key,
    required this.trackingId,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('آرڈر لائیو ٹریکنگ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<OrderModel?>(
        stream: orderProvider.trackOrderByTrackingId(trackingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'خرابی: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final order = snapshot.data;

          if (order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'ٹریکنگ آئی ڈی "$trackingId" کا کوئی آرڈر نہیں ملا۔',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'برائے مہربانی ٹریکنگ آئی ڈی دوبارہ چیک کریں۔',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final currentStatusIndex =
              AppStrings.orderStatuses.indexOf(order.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🎫 Header Tracking Ticket
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'MILL TRACKING ID',
                        style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 2,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        order.trackingId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Divider(color: Colors.white30, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('کسٹمر نام',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(order.customerName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('کیٹیگری',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(order.category,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 🔄 Live Status Stepper Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'موجودہ حالت (Current Status):',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.status,
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Custom Stepper List
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: AppStrings.orderStatuses.length,
                          itemBuilder: (context, index) {
                            final statusName = AppStrings.orderStatuses[index];
                            final isCompleted = index <= currentStatusIndex;
                            final isCurrent = index == currentStatusIndex;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCompleted
                                            ? AppColors.secondary
                                            : Colors.grey.shade300,
                                        border: isCurrent
                                            ? Border.all(
                                                color: AppColors.primary,
                                                width: 3)
                                            : null,
                                      ),
                                      child: Icon(
                                        isCompleted
                                            ? Icons.check_rounded
                                            : Icons.circle,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (index <
                                        AppStrings.orderStatuses.length - 1)
                                      Container(
                                        width: 3,
                                        height: 36,
                                        color: index < currentStatusIndex
                                            ? AppColors.secondary
                                            : Colors.grey.shade300,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        statusName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isCompleted
                                              ? AppColors.textDark
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                      if (isCurrent)
                                        Text(
                                          'آخری اپڈیٹ: ${DateFormat('hh:mm a').format(order.updatedAt)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 💵 Payment & Order Details Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تفصیلات آرڈر (Order Details)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Divider(),
                        _buildDetailRow(
                            'مقدار / وزن:', '${order.quantity} ${order.unit}'),
                        _buildDetailRow(
                            'ریٹ فی کلو:', 'Rs ${order.ratePerKg}'),
                        _buildDetailRow(
                            'کل بل:', 'Rs ${order.totalAmount.toStringAsFixed(1)}'),
                        _buildDetailRow(
                            'وصول شدہ:', 'Rs ${order.paidAmount.toStringAsFixed(1)}'),
                        _buildDetailRow(
                          'باقیداری:',
                          'Rs ${order.remainingAmount.toStringAsFixed(1)}',
                          isBold: true,
                          color: order.remainingAmount > 0
                              ? Colors.red
                              : AppColors.secondary,
                        ),
                        _buildDetailRow('ادائیگی کی حالت:', order.paymentStatus),
                        _buildDetailRow('آرڈر کی تاریخ:',
                            DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}