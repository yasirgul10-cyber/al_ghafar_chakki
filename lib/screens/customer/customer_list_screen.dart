// lib/screens/customer/customer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart'; // 👈 کسٹمر پرووائیڈر کا امپورٹ
import 'customer_ledger_screen.dart'; // 👈 کسٹمر لیجر اسکرین کا امپورٹ

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({Key? key}) : super(key: key);

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // سرچ کیوری اپڈیٹ کرنے کا فنکشن
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  // کل وصولی (Receivable) معلوم کرنے کا حساب
  double _calculateTotalReceivable(List<CustomerModel> customers) {
    return customers
        .where((c) => c.balance > 0)
        .fold(0.0, (sum, item) => sum + item.balance);
  }

  // کل ادائیگی (Payable) معلوم کرنے کا حساب
  double _calculateTotalPayable(List<CustomerModel> customers) {
    return customers
        .where((c) => c.balance < 0)
        .fold(0.0, (sum, item) => sum + item.balance.abs());
  }

  @override
  Widget build(BuildContext context) {
    // CustomerProvider سے رئیل ٹائم ڈیٹا حاصل کرنا
    final customerProvider = context.watch<CustomerProvider>();
    final List<CustomerModel> allCustomers = customerProvider.customers;

    // سرچ کیوری کے مطابق فلٹر کی گئی لسٹ
    final List<CustomerModel> filteredCustomers = _searchQuery.isEmpty
        ? allCustomers
        : allCustomers.where((customer) {
            final nameLower = customer.name.toLowerCase();
            final phoneLower = customer.phone.toLowerCase();
            final addressLower = customer.address.toLowerCase();

            return nameLower.contains(_searchQuery) ||
                phoneLower.contains(_searchQuery) ||
                addressLower.contains(_searchQuery);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'گاہکوں کی فہرست (Customer List)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: Column(
        children: [
          _buildSummaryCard(allCustomers),
          _buildSearchBar(),
          Expanded(
            child: filteredCustomers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      return _buildCustomerCard(customer);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerBottomSheet(context),
        backgroundColor: const Color(0xFF1E3C72),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'نیا گاہک',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<CustomerModel> customers) {
    final totalReceivable = _calculateTotalReceivable(customers);
    final totalPayable = _calculateTotalPayable(customers);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            title: 'کل گاہک',
            value: '${customers.length}',
            icon: Icons.people,
            color: Colors.white,
          ),
          Container(height: 35, width: 1, color: Colors.white30),
          _buildSummaryItem(
            title: 'کل ادھار (لینا ہے)',
            value: 'Rs. ${totalReceivable.toStringAsFixed(0)}',
            icon: Icons.arrow_downward,
            color: Colors.redAccent[100]!,
          ),
          Container(height: 35, width: 1, color: Colors.white30),
          _buildSummaryItem(
            title: 'کل جمع (دینا ہے)',
            value: 'Rs. ${totalPayable.toStringAsFixed(0)}',
            icon: Icons.arrow_upward,
            color: Colors.greenAccent[100]!,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'نام، فون نمبر یا پتہ سے تلاش کریں...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3C72)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    final bool isReceivable = customer.balance > 0;
    final bool isPayable = customer.balance < 0;

    Color balanceColor = Colors.grey[700]!;
    String balanceStatusText = 'حساب برابر';

    if (isReceivable) {
      balanceColor = Colors.red[700]!;
      balanceStatusText = 'ادھار (لینا ہے)';
    } else if (isPayable) {
      balanceColor = Colors.green[700]!;
      balanceStatusText = 'جمع (دینا ہے)';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // 👈 گاہک کے لیجر کی اسکرین پر نیویگیشن
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerLedgerScreen(
                customerName: customer.name,
                customerPhone: customer.phone,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF1E3C72).withOpacity(0.1),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0] : 'C',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3C72),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          customer.phone,
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.address,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${customer.balance.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: balanceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      balanceStatusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: balanceColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 70, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'کوئی گاہک نہیں ملا',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'براہ کرم درست نام، فون یا پتہ لکھیں۔',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerBottomSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final balanceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'نیا گاہک شامل کریں',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'گاہک کا نام',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'فون نمبر',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'پتہ',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ابتدائی ادھار / بیلنس (اگر ہے)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      final double initialBalance =
                          double.tryParse(balanceController.text.trim()) ?? 0.0;

                      // 👈 Firestore کے لیے کسٹمر کا نیا ماڈل
                      final newCustomer = CustomerModel(
                        id: '', // Firestore خود Auto-ID جنریٹ کرے گا
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        address: addressController.text.trim(),
                        balance: initialBalance,
                      );

                      // 👈 Firestore / Provider میں ڈیٹا محفوظ کرنا
                      final success = await context
                          .read<CustomerProvider>()
                          .addCustomer(newCustomer);

                      if (success && context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text(
                    'گاہک محفوظ کریں',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}