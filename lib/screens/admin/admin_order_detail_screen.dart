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
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late String _currentStatus;

  final TextEditingController _paymentController =
      TextEditingController();

  bool _isUpdatingStatus = false;
  bool _isUpdatingPayment = false;

  @override
  void initState() {
    super.initState();

    _currentStatus = AppStrings.orderStatuses.contains(widget.order.status)
        ? widget.order.status
        : AppStrings.orderStatuses.first;
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  // ============================================================
  // STATUS UPDATE
  // ============================================================

  Future<void> _handleStatusUpdate() async {
    if (_currentStatus == widget.order.status) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    final provider = Provider.of<OrderProvider>(
      context,
      listen: false,
    );

    final success = await provider.updateOrderStatus(
      widget.order.id,
      _currentStatus,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingStatus = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'آرڈر کا اسٹیٹس کامیابی سے اپڈیٹ ہو گیا!',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                'اسٹیٹس اپڈیٹ کرنے میں ناکامی',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // PAYMENT DIALOG
  // ============================================================

  void _showPaymentDialog() {
    final remainingAmount = widget.order.remainingAmount;

    if (remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اس آرڈر کی مکمل ادائیگی ہو چکی ہے۔',
          ),
        ),
      );
      return;
    }

    _paymentController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'نئی ادائیگی وصول کریں',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _paymentSummaryRow(
                'کل بل',
                widget.order.totalAmount,
              ),
              const SizedBox(height: 6),
              _paymentSummaryRow(
                'پہلے وصول شدہ',
                widget.order.paidAmount,
              ),
              const SizedBox(height: 6),
              _paymentSummaryRow(
                'باقی رقم',
                remainingAmount,
                isHighlighted: true,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _paymentController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'نئی ادائیگی',
                  hintText: 'مثلاً .0.00',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('منسوخ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final newPayment = double.tryParse(
                  _paymentController.text.trim(),
                );

                if (newPayment == null || newPayment <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'درست ادائیگی کی رقم درج کریں',
                      ),
                    ),
                  );
                  return;
                }

                if (newPayment > remainingAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'نئی ادائیگی باقی رقم سے زیادہ نہیں ہو سکتی',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                _handlePaymentUpdate(newPayment);
              },
              child: const Text('ادائیگی وصول کریں'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PAYMENT UPDATE
  // ============================================================

  Future<void> _handlePaymentUpdate(
    double newPayment,
  ) async {
    if (newPayment <= 0) {
      return;
    }

    final remainingAmount = widget.order.remainingAmount;

    if (newPayment > remainingAmount) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ادائیگی باقی رقم سے زیادہ نہیں ہو سکتی',
          ),
        ),
      );

      return;
    }

    final newPaidAmount =
        widget.order.paidAmount + newPayment;

    setState(() {
      _isUpdatingPayment = true;
    });

    final provider = Provider.of<OrderProvider>(
      context,
      listen: false,
    );

    final success = await provider.updatePaymentDetails(
      orderId: widget.order.id,
      newPaidAmount: newPaidAmount,
      totalAmount: widget.order.totalAmount,
      customerName: widget.order.customerName,
      customerPhone: widget.order.phone,
      trackingId: widget.order.trackingId,
      addedPayment: newPayment,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingPayment = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rs ${newPayment.toStringAsFixed(0)} کی ادائیگی وصول ہو گئی۔',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                'پیمنٹ اپڈیٹ میں ناکامی',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // PAYMENT SUMMARY ROW
  // ============================================================

  Widget _paymentSummaryRow(
    String label,
    double amount, {
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlighted
                ? AppColors.primary
                : AppColors.textMuted,
            fontWeight:
                isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          'Rs ${amount.toStringAsFixed(1)}',
          style: TextStyle(
            fontWeight:
                isHighlighted ? FontWeight.bold : FontWeight.w600,
            color: isHighlighted
                ? AppColors.primary
                : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 53.0,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'آرڈر تفصیل: ${order.trackingId}',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====================================================
            // STATUS CARD
            // ====================================================

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لائیو اسٹیٹس تبدیل کریں',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _currentStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: AppStrings.orderStatuses.map(
                        (status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _currentStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onPressed: _isUpdatingStatus
                            ? null
                            : _handleStatusUpdate,
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                              ),
                        label: const Text(
                          'اسٹیٹس محفوظ کریں',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ====================================================
            // CUSTOMER + ORDER DETAILS
            // ====================================================

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    _buildRow(
                      'کسٹمر نام:',
                      order.customerName,
                    ),
                    _buildRow(
                      'فون نمبر:',
                      order.phone,
                    ),
                    _buildRow(
                      'کیٹیگری:',
                      order.category,
                    ),
                    _buildRow(
                      'وزن/مقدار:',
                      '${order.quantity} ${order.unit}',
                    ),
                    _buildRow(
                      'ریٹ فی کلو:',
                      'Rs ${order.ratePerKg.toStringAsFixed(1)}',
                    ),
                    _buildRow(
                      'آرڈر کی تاریخ:',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(order.createdAt),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ====================================================
            // PAYMENT CARD
            // ====================================================

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'حساب کتاب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (order.remainingAmount > 0)
                          IconButton(
                            icon: const Icon(
                              Icons.payments_outlined,
                              color: AppColors.secondary,
                            ),
                            tooltip: 'نئی ادائیگی وصول کریں',
                            onPressed: _isUpdatingPayment
                                ? null
                                : _showPaymentDialog,
                          ),
                      ],
                    ),
                    const Divider(),
                    _buildRow(
                      'کل رقم:',
                      'Rs ${order.totalAmount.toStringAsFixed(1)}',
                    ),
                    _buildRow(
                      'وصول شدہ:',
                      'Rs ${order.paidAmount.toStringAsFixed(1)}',
                    ),
                    _buildRow(
                      'باقی رقم:',
                      'Rs ${order.remainingAmount.toStringAsFixed(1)}',
                      isBold: true,
                      color: order.remainingAmount > 0
                          ? Colors.red
                          : AppColors.secondary,
                    ),
                    _buildRow(
                      'ادائیگی کی حالت:',
                      order.paymentStatus,
                      isBold: true,
                      color: order.paymentStatus ==
                              AppStrings.paymentPaid
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                    if (_isUpdatingPayment) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMMON ROW
  // ============================================================

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: color ?? AppColors.textDark,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}