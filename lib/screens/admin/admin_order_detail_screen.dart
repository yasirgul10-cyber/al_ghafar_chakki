import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const AdminOrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late String _currentStatus;
  final TextEditingController _paymentController = TextEditingController();
  bool _isUpdatingStatus = false;
  bool _isUpdatingPayment = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  // 🔄 Update Status Logic
  Future<void> _handleStatusUpdate() async {
    if (_currentStatus == widget.order.status) return;

    setState(() => _isUpdatingStatus = true);

    final provider = Provider.of<OrderProvider>(context, listen: false);
    final success = await provider.updateOrderStatus(
      widget.order.id,
      _currentStatus,
    );

    setState(() => _isUpdatingStatus = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('آرڈر کا اسٹیٹس کامیابی سے اپڈیٹ ہو گیا!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'اسٹیٹس اپڈیٹ کرنے میں ناکامی'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 💵 Open Dialog to Receive Cash / Update Paid Amount
  void _showPaymentDialog() {
    _paymentController.text = widget.order.paidAmount.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('ادائیگی اپڈیٹ کریں'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('کل بل: Rs ${widget.order.totalAmount.toStringAsFixed(1)}'),
              const SizedBox(height: 12),
              TextField(
                controller: _paymentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'کل وصول شدہ رقم (Paid Amount)',
                  border: OutlineInputBorder(),
                  prefixText: 'Rs ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('منسوخ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final double? newPaid = double.tryParse(_paymentController.text);

                if (newPaid == null || newPaid < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('درست رقم درج کریں')),
                  );
                  return;
                }

                if (newPaid > widget.order.totalAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('وصول شدہ رقم کل بل سے زیادہ نہیں ہو سکتی')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _handlePaymentUpdate(newPaid);
              },
              child: const Text('محفوظ کریں'),
            ),
          ],
        );
      },
    );
  }

  // 💵 Update Payment Logic (Updated with Ledger Integration Details)
  Future<void> _handlePaymentUpdate(double newPaidAmount) async {
    setState(() => _isUpdatingPayment = true);

    final provider = Provider.of<OrderProvider>(context, listen: false);

    // پرانی رقم اور نئی وصول شدہ رقم کا فرق
    final addedPayment = newPaidAmount - widget.order.paidAmount;

    final success = await provider.updatePaymentDetails(
      orderId: widget.order.id,
      newPaidAmount: newPaidAmount,
      totalAmount: widget.order.totalAmount,
      customerName: widget.order.customerName,
      customerPhone: widget.order.phone,
      trackingId: widget.order.trackingId,
      addedPayment: addedPayment,
    );

    setState(() => _isUpdatingPayment = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ادائیگی کی تفاصیل اپڈیٹ ہو گئیں!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'پیمنٹ اپڈیٹ میں ناکامی'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(
        title: Text('آرڈر تفصیل: ${order.trackingId}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔄 Change Order Status Section Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لائیو اسٹیٹس تبدیل کریں (Update Live Status)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _currentStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: AppStrings.orderStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _currentStatus = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isUpdatingStatus ? null : _handleStatusUpdate,
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('اسٹیٹس محفوظ کریں'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 💵 Customer & Item Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'کسٹمر اور آرڈر کی تفصیلات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Divider(),
                    _buildRow('کسٹمر نام:', order.customerName),
                    _buildRow('فون نمبر:', order.phone),
                    _buildRow('کیٹیگری:', order.category),
                    _buildRow('وزن/مقدار:', '${order.quantity} ${order.unit}'),
                    _buildRow('ریٹ فی کلو:', 'Rs ${order.ratePerKg}'),
                    _buildRow('آرڈر کی تاریخ:',
                        DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 💰 Payment & Ledger Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'حساب کتاب (Payment Ledger)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.secondary),
                          onPressed:
                              _isUpdatingPayment ? null : _showPaymentDialog,
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildRow('کل رقم:', 'Rs ${order.totalAmount.toStringAsFixed(1)}'),
                    _buildRow('وصول شدہ:', 'Rs ${order.paidAmount.toStringAsFixed(1)}'),
                    _buildRow(
                      'باقیداری:',
                      'Rs ${order.remainingAmount.toStringAsFixed(1)}',
                      isBold: true,
                      color: order.remainingAmount > 0
                          ? Colors.red
                          : AppColors.secondary,
                    ),
                    _buildRow('ادائیگی کی حالت:', order.paymentStatus),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textDark,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}