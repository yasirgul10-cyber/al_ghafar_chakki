import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/ledger_transaction.dart';
import '../../models/order_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/order_provider.dart';
import '../tracking/qr_scanner_screen.dart';
import 'admin_order_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  // Active Metric Filter: 'orders', 'sale', 'received', 'remaining', 'udhaar', 'pending', null
  String? _selectedCardMetric;

  // Date Filter State
  DateTimeRange? _selectedDateRange;

  late Stream<List<OrderModel>> _ordersStream;
  late Stream<List<LedgerTransaction>> _ledgerStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    _ordersStream = context.read<OrderProvider>().getAllOrdersStream();
    _ledgerStream = context.read<LedgerProvider>().getAllLedgerTransactionsStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _initStreams();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );

    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newRange != null) {
      setState(() {
        _selectedDateRange = newRange;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  void _scanQR() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _searchController.text = scannedCode;
      setState(() {
        _searchQuery = scannedCode;
      });
    }
  }

  // PDF Export Method
  Future<void> _generateAndDownloadPdfReport({
    required String dateTitle,
    required int totalOrders,
    required double totalSale,
    required double totalReceived,
    required double totalRemaining,
    required double totalReceivable,
    required int pendingOrders,
    required List<OrderModel> reportOrders,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AL-GHAFFAR CHAKKI',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.brown800,
                        ),
                      ),
                      pw.Text(
                        'Business Summary Report ($dateTitle)',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Summary Grid Table
            pw.Table.fromTextArray(
              headers: ['Metric Name', 'Value'],
              data: [
                ['Total Orders', '$totalOrders'],
                ['Total Sale', 'Rs. ${totalSale.toStringAsFixed(0)}'],
                ['Total Received', 'Rs. ${totalReceived.toStringAsFixed(0)}'],
                ['Remaining Amount', 'Rs. ${totalRemaining.toStringAsFixed(0)}'],
                ['Total Udhaar (Receivable)', 'Rs. ${totalReceivable.toStringAsFixed(0)}'],
                ['Pending Orders', '$pendingOrders'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
              cellAlignment: pw.Alignment.centerLeft,
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              'Orders List Details',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            // Orders Table
            pw.Table.fromTextArray(
              headers: ['Tracking ID', 'Customer Name', 'Item & Qty', 'Total Amount', 'Status'],
              data: reportOrders.map((o) {
                return [
                  o.trackingId,
                  o.customerName,
                  '${o.category} (${o.quantity} ${o.unit})',
                  'Rs. ${o.totalAmount.toStringAsFixed(0)}',
                  '${o.status} / ${o.paymentStatus}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'AlGhaffar_Report_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(132.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF9100),
                Color(0xFFE65100),
                Color(0xFFBF360C),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Back',
                ),
                const Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 0,
                    bottom: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grass_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                      SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'الغفار چکی',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'AL-GHAFFAR CHAKKI',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        child: StreamBuilder<List<OrderModel>>(
          stream: _ordersStream,
          builder: (context, orderSnapshot) {
            if (orderSnapshot.hasError) {
              return _buildError(
                'Orders load nahi ho rahe.\n${orderSnapshot.error}',
              );
            }

            if (orderSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = orderSnapshot.data ?? <OrderModel>[];

            return StreamBuilder<List<LedgerTransaction>>(
              stream: _ledgerStream,
              builder: (context, ledgerSnapshot) {
                if (ledgerSnapshot.hasError) {
                  return _buildError(
                    'Ledger load nahi ho raha.\n${ledgerSnapshot.error}',
                  );
                }

                if (ledgerSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions =
                    ledgerSnapshot.data ?? <LedgerTransaction>[];

                // Search & Filter Logic
                final cleanQuery = _searchQuery.trim().toLowerCase();
                final filteredOrders = orders.where((order) {
                  final matchesSearch = cleanQuery.isEmpty ||
                      order.trackingId.toLowerCase().contains(cleanQuery) ||
                      order.customerName.toLowerCase().contains(cleanQuery) ||
                      order.phone.contains(cleanQuery);

                  final matchesFilter = _selectedFilter == 'All' ||
                      order.status == _selectedFilter;

                  return matchesSearch && matchesFilter;
                }).toList();

                return _LiveDashboardContent(
                  orders: orders,
                  filteredOrders: filteredOrders,
                  transactions: transactions,
                  searchQuery: _searchQuery,
                  searchController: _searchController,
                  selectedFilter: _selectedFilter,
                  selectedDateRange: _selectedDateRange,
                  selectedCardMetric: _selectedCardMetric,
                  onSearchChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  onFilterChanged: (newFilter) {
                    setState(() {
                      _selectedFilter = newFilter;
                    });
                  },
                  onCardMetricSelected: (metric) {
                    setState(() {
                      if (_selectedCardMetric == metric) {
                        _selectedCardMetric = null; // Toggle OFF
                      } else {
                        _selectedCardMetric = metric; // Toggle ON
                      }
                    });
                  },
                  onQrScanPressed: _scanQR,
                  onPickDateRangePressed: _pickDateRange,
                  onClearDateFilterPressed: _clearDateFilter,
                  onExportPdfPressed: (dateTitle, totalOrders, totalSale, totalReceived, totalRemaining, totalReceivable, pendingOrders, reportOrders) {
                    _generateAndDownloadPdfReport(
                      dateTitle: dateTitle,
                      totalOrders: totalOrders,
                      totalSale: totalSale,
                      totalReceived: totalReceived,
                      totalRemaining: totalRemaining,
                      totalReceivable: totalReceivable,
                      pendingOrders: pendingOrders,
                      reportOrders: reportOrders,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _LiveDashboardContent extends StatelessWidget {
  final List<OrderModel> orders;
  final List<OrderModel> filteredOrders;
  final List<LedgerTransaction> transactions;
  final String searchQuery;
  final TextEditingController searchController;
  final String selectedFilter;
  final DateTimeRange? selectedDateRange;
  final String? selectedCardMetric;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onCardMetricSelected;
  final VoidCallback onQrScanPressed;
  final VoidCallback onPickDateRangePressed;
  final VoidCallback onClearDateFilterPressed;
  final Function(
    String dateTitle,
    int totalOrders,
    double totalSale,
    double totalReceived,
    double totalRemaining,
    double totalReceivable,
    int pendingOrders,
    List<OrderModel> reportOrders,
  ) onExportPdfPressed;

  const _LiveDashboardContent({
    required this.orders,
    required this.filteredOrders,
    required this.transactions,
    required this.searchQuery,
    required this.searchController,
    required this.selectedFilter,
    required this.selectedDateRange,
    required this.selectedCardMetric,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onCardMetricSelected,
    required this.onQrScanPressed,
    required this.onPickDateRangePressed,
    required this.onClearDateFilterPressed,
    required this.onExportPdfPressed,
  });

  bool _isDateInRange(DateTime date) {
    if (selectedDateRange == null) {
      final now = DateTime.now();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }

    final start = DateTime(
      selectedDateRange!.start.year,
      selectedDateRange!.start.month,
      selectedDateRange!.start.day,
    );
    final end = DateTime(
      selectedDateRange!.end.year,
      selectedDateRange!.end.month,
      selectedDateRange!.end.day,
      23,
      59,
      59,
    );

    return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
        date.isBefore(end.add(const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    // Filtered orders & transactions by date range
    final rangeOrders = orders.where((order) {
      return _isDateInRange(order.createdAt);
    }).toList();

    final rangeTransactions = transactions.where((transaction) {
      return _isDateInRange(transaction.date);
    }).toList();

    final totalOrderCount = rangeOrders.length;

    final totalSale = rangeOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );

    final totalReceived = rangeTransactions
        .where((transaction) => transaction.isCredit)
        .fold<double>(
          0,
          (sum, transaction) => sum + transaction.amount,
        );

    final totalRemaining = rangeOrders.fold<double>(
      0,
      (sum, order) => sum + order.remainingAmount,
    );

    final customerProvider = context.watch<CustomerProvider>();

    final totalReceivable = customerProvider.customers
        .where((customer) => customer.balance > 0)
        .fold<double>(
          0,
          (sum, customer) => sum + customer.balance,
        );

    final pendingOrders = rangeOrders.where((order) {
      return order.status != 'Delivered';
    }).length;

    // Filter displayed list based on selectedCardMetric
    List<OrderModel> cardFilteredOrders = List.from(filteredOrders);
    List<LedgerTransaction> cardFilteredTransactions = List.from(rangeTransactions);

    if (selectedCardMetric != null) {
      switch (selectedCardMetric) {
        case 'orders':
          cardFilteredOrders = rangeOrders;
          break;
        case 'sale':
          cardFilteredOrders = rangeOrders.where((o) => o.totalAmount > 0).toList();
          break;
        case 'received':
          cardFilteredTransactions = rangeTransactions.where((t) => t.isCredit).toList();
          break;
        case 'remaining':
          cardFilteredOrders = rangeOrders.where((o) => o.remainingAmount > 0).toList();
          break;
        case 'udhaar':
          cardFilteredOrders = rangeOrders.where((o) => o.paymentStatus != 'Paid').toList();
          break;
        case 'pending':
          cardFilteredOrders = rangeOrders.where((o) => o.status != 'Delivered').toList();
          break;
      }
    }

    final recentTransactions = List<LedgerTransaction>.from(
      selectedCardMetric == 'received' ? cardFilteredTransactions : transactions,
    )..sort((a, b) => b.date.compareTo(a.date));

    final recent = recentTransactions.take(8).toList();

    final dateTitle = selectedDateRange == null
        ? 'Aaj Ka Hisab'
        : '${DateFormat('dd MMM').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Report Action Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E2723),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedCardMetric != null
                                ? "Filtering by: ${selectedCardMetric!.toUpperCase()}"
                                : "Tap card below to filter list",
                            style: TextStyle(
                              fontSize: 11,
                              color: selectedCardMetric != null
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                              fontWeight: selectedCardMetric != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            onExportPdfPressed(
                              dateTitle,
                              totalOrderCount,
                              totalSale,
                              totalReceived,
                              totalRemaining,
                              totalReceivable,
                              pendingOrders,
                              rangeOrders,
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                          tooltip: 'Export PDF Report',
                        ),
                        ElevatedButton.icon(
                          onPressed: onPickDateRangePressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_month_rounded, size: 15),
                          label: Text(
                            selectedDateRange == null ? 'Date Set' : 'Change',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (selectedDateRange != null) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.grey, size: 20),
                            tooltip: 'Reset Today',
                            onPressed: onClearDateFilterPressed,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Interactive Clickable Summaries (Row 1)
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Orders',
                        value: '$totalOrderCount',
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF1565C0),
                        isSelected: selectedCardMetric == 'orders',
                        onTap: () => onCardMetricSelected('orders'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Sale',
                        value: _formatMoney(totalSale),
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF2E7D32),
                        isSelected: selectedCardMetric == 'sale',
                        onTap: () => onCardMetricSelected('sale'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Interactive Clickable Summaries (Row 2)
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Received',
                        value: _formatMoney(totalReceived),
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF00897B),
                        isSelected: selectedCardMetric == 'received',
                        onTap: () => onCardMetricSelected('received'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Remaining',
                        value: _formatMoney(totalRemaining),
                        icon: Icons.pending_actions_rounded,
                        color: const Color(0xFFC62828),
                        isSelected: selectedCardMetric == 'remaining',
                        onTap: () => onCardMetricSelected('remaining'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Interactive Clickable Summaries (Row 3)
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Udhaar',
                        value: _formatMoney(totalReceivable),
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF6A1B9A),
                        isSelected: selectedCardMetric == 'udhaar',
                        onTap: () => onCardMetricSelected('udhaar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Pending Orders',
                        value: '$pendingOrders',
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFFEF6C00),
                        isSelected: selectedCardMetric == 'pending',
                        onTap: () => onCardMetricSelected('pending'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // Active Card Filter Clear Banner
                if (selectedCardMetric != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Displaying ${selectedCardMetric!.toUpperCase()} data list',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onCardMetricSelected(selectedCardMetric!),
                          child: const Row(
                            children: [
                              Text(
                                'All Show Karein',
                                style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.close_rounded, size: 16, color: Colors.red),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Search & Filter Section
                const Text(
                  'آرڈرز کی تلاش اور فلٹر (Search & Filter)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 12),

                // Search Bar with QR Scanner
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ٹریکنگ ID یا کسٹمر کے نام سے تلاش کریں...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppColors.primary,
                          ),
                          tooltip: 'QR Scan Karein',
                          onPressed: onQrScanPressed,
                        ),
                        if (searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          ),
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'تمام'),
                      ...AppStrings.orderStatuses.map((status) {
                        return _buildFilterChip(status, status);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Filtered Orders List
                if (cardFilteredOrders.isEmpty)
                  _buildEmptyOrders()
                else
                  ...cardFilteredOrders.map(
                    (order) => _buildOrderCard(context, order),
                  ),

                const SizedBox(height: 26),

                // Recent Transactions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aakhri Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    Text(
                      '${recent.length} entries',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (recent.isEmpty)
                  _buildEmptyTransactions()
                else
                  ...recent.map(
                    (transaction) => _buildTransactionItem(transaction),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.2 : 0.08),
              blurRadius: isSelected ? 14 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color : Colors.grey.shade600,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textDark,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            onFilterChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    final isPaid = order.paymentStatus == AppStrings.paymentPaid;
    final isUnpaid = order.paymentStatus == AppStrings.paymentUnpaid;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: order.trackingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tracking ID (${order.trackingId}) copy ho gayi hai!',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              order.trackingId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${order.category} - ${order.quantity} ${order.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatMoney(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.paymentStatus,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPaid
                              ? Colors.green.shade700
                              : isUnpaid
                                  ? Colors.red.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(LedgerTransaction transaction) {
    final isPayment = transaction.isCredit;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isPayment ? Colors.green.shade50 : Colors.red.shade50,
            child: Icon(
              isPayment
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isPayment ? Colors.green.shade700 : Colors.red.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMoney(transaction.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPayment ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatTime(transaction.date),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          'کوئی آرڈر نہیں ملا',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Abhi koi transaction nahi hai.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}