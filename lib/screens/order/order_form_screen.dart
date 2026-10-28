import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../tracking/tracking_screen.dart';

class OrderFormScreen extends StatefulWidget {
  final String selectedCategory;

  const OrderFormScreen({
    super.key,
    required this.selectedCategory,
  });

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();

  late String _currentCategory;
  String _selectedUnit = AppStrings.unitKg;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.selectedCategory;
    _resetFormValues();
  }

  void _resetFormValues() {
    _rateController.text =
        _currentCategory == AppStrings.categoryWheat ? '15' : '50';
    _paidController.text = '0';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  // 🔄 Swipe to Refresh Function
  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _quantityController.clear();
      _resetFormValues();
    });
  }

  // 🧮 Live Weight Calculation in KG
  double get _quantityInKg {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    switch (_selectedUnit) {
      case AppStrings.unitGram:
        return qty / 1000.0;
      case AppStrings.unitMann:
        return qty * 40.0;
      case AppStrings.unitKg:
      default:
        return qty;
    }
  }

  // 💵 Live Financial Calculations
  double get _totalAmount {
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    return _quantityInKg * rate;
  }

  double get _paidAmount => double.tryParse(_paidController.text) ?? 0.0;

  double get _remainingAmount {
    final rem = _totalAmount - _paidAmount;
    return rem < 0 ? 0.0 : rem;
  }

  // 🖨️ Thermal Receipt Printing Method
  Future<void> _printOrderReceipt(OrderModel order) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'AL-GHAFFAR CHAKKI',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text('Order Cash Receipt', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              pw.Text(
                'Tracking: ${order.trackingId}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
              pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(order.customerName,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('${order.category} (${order.quantity} ${order.unit})',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rate:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Rs ${order.ratePerKg.toStringAsFixed(1)}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Amount:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs ${order.totalAmount.toStringAsFixed(1)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Rs ${order.paidAmount.toStringAsFixed(1)}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Remaining:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Rs ${order.remainingAmount.toStringAsFixed(1)}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Shukriya! Phir Tashreef Layein.',
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${order.trackingId}.pdf',
    );
  }

  // 🚀 Safe Submit Order with Timeout & Exceptions
  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<OrderProvider>(
      context,
      listen: false,
    );

    try {
      final createdOrder = await provider
          .createOrder(
            customerName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            category: _currentCategory,
            quantity: double.tryParse(_quantityController.text) ?? 0.0,
            unit: _selectedUnit,
            ratePerKg: double.tryParse(_rateController.text) ?? 0.0,
            paidAmount: _paidAmount,
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (!mounted) {
        return;
      }

      if (createdOrder != null) {
        _showSuccessDialog(createdOrder);
        return;
      }

      final error = provider.errorMessage ??
          'آرڈر محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase سے جواب آنے میں زیادہ وقت لگ رہا ہے۔ '
            'Internet connection اور Firebase configuration چیک کریں۔',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'آرڈر محفوظ کرتے وقت مسئلہ آیا: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(OrderModel order) {
    final formattedDateTime = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 28),
            SizedBox(width: 8),
            Text('آرڈر محفوظ ہو گیا!', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tracking ID Container with Copy Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ٹریکنگ آئی ڈی (Tracking ID)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: SelectableText(
                            order.trackingId,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: order.trackingId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tracking ID (${order.trackingId}) copy ho gayi hai!'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // QR Code
              SizedBox(
                height: 130,
                width: 130,
                child: QrImageView(
                  data: order.trackingId,
                  version: QrVersions.auto,
                  size: 130.0,
                ),
              ),

              const SizedBox(height: 12),

              // Customer Details & Date Time Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'کسٹمر: ${order.customerName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'کل رقم: Rs ${order.totalAmount.toStringAsFixed(1)} | وصول: Rs ${order.paidAmount.toStringAsFixed(1)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          formattedDateTime,
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _printOrderReceipt(order),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('پرنٹ انوائس'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackingScreen(trackingId: order.trackingId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('لائیو ٹریکنگ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('ہوم پر جائیں', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<OrderProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 53.0,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('نیا آرڈر فارم (New Order)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🌾 Category Selector Dropdown
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentCategory,
                        isExpanded: true,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: AppStrings.categoryWheat,
                            child: Text(
                              '🌾 آٹا پسائی (Wheat Grinding)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: AppStrings.categorySpices,
                            child: Text(
                              '🌶️ مصالحہ پسائی (Spices Grinding)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _currentCategory = val;
                              _resetFormValues();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 👤 Customer Details Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'کسٹمر کی معلومات (Customer Info)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'کسٹمر کا نام (Customer Name)',
                            prefixIcon: Icon(Icons.person_rounded),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'نام درج کریں' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'موبائل نمبر (Mobile Number)',
                            prefixIcon: Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'نمبر درج کریں' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ⚖️ Weight & Rate Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'وزن اور ریٹ (Weight & Billing)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'مقدار (Quantity)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  final n = double.tryParse(val ?? '');
                                  if (n == null || n <= 0) return 'مقدار درج کریں';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedUnit,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'اکائی (Unit)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: AppStrings.unitKg,
                                    child: Text('KG', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: AppStrings.unitGram,
                                    child: Text('Gram', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: AppStrings.unitMann,
                                    child: Text('Mann (40 KG)', overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedUnit = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _rateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'ریٹ فی کلو',
                                  prefixText: 'Rs ',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  final r = double.tryParse(val ?? '');
                                  if (r == null || r <= 0) return 'ریٹ درج کریں';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _paidController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'وصول شدہ (Paid)',
                                  prefixText: 'Rs ',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 💵 Live Calculated Bill Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('مجموعی وزن (KG):', style: TextStyle(fontSize: 15)),
                          Text('${_quantityInKg.toStringAsFixed(2)} KG',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('کل بل (Total Amount):', style: TextStyle(fontSize: 15)),
                          Text('Rs ${_totalAmount.toStringAsFixed(1)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('بقایا رقم (Remaining):', style: TextStyle(fontSize: 15)),
                          Text('Rs ${_remainingAmount.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _remainingAmount > 0
                                    ? Colors.red.shade700
                                    : AppColors.secondary,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 🚀 Submit Order Button
                ElevatedButton(
                  onPressed: isLoading ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'آرڈر سبمٹ کریں (Submit Order)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}