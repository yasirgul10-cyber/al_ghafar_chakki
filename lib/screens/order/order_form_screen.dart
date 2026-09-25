import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  // 🔄 Swip to Refresh Function
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

  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<OrderProvider>(context, listen: false);

    final createdOrder = await provider.createOrder(
      customerName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      category: _currentCategory,
      quantity: double.tryParse(_quantityController.text) ?? 0.0,
      unit: _selectedUnit,
      ratePerKg: double.tryParse(_rateController.text) ?? 0.0,
      paidAmount: _paidAmount,
    );

    if (createdOrder != null && mounted) {
      _showSuccessDialog(createdOrder);
    } else if (mounted && provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 28),
            SizedBox(width: 8),
            Text('آرڈر محفوظ ہو گیا!', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('ٹریکنگ آئی ڈی (Tracking ID)'),
                    SelectableText(
                      order.trackingId,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Dynamic QR Code for generated tracking ID
              SizedBox(
                height: 150,
                width: 150,
                child: QrImageView(
                  data: order.trackingId,
                  version: QrVersions.auto,
                  size: 150.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'کسٹمر: ${order.customerName}\nکل رقم: Rs ${order.totalAmount.toStringAsFixed(1)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('ہوم پر جائیں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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
            child: const Text('لائیو ٹریکنگ دیکھیں'),
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
                        items: const [
                          DropdownMenuItem(
                            value: AppStrings.categoryWheat,
                            child: Text('🌾 ' + AppStrings.categoryWheat),
                          ),
                          DropdownMenuItem(
                            value: AppStrings.categorySpices,
                            child: Text('🌶️ ' + AppStrings.categorySpices),
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
                              flex: 2,
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'مقدار (Quantity)',
                                  border: OutlineInputBorder(),
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
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'اکائی (Unit)',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: AppStrings.unitKg,
                                    child: Text('KG'),
                                  ),
                                  DropdownMenuItem(
                                    value: AppStrings.unitGram,
                                    child: Text('Gram'),
                                  ),
                                  DropdownMenuItem(
                                    value: AppStrings.unitMann,
                                    child: Text('Mann (40 KG)'),
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