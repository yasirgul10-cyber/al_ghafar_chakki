import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../models/ledger_transaction.dart';
import '../../providers/ledger_provider.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final String customerName;
  final String customerPhone;

  const CustomerLedgerScreen({
    super.key,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  // 📝 نیا اندراج شامل کرنے کا ڈائیلاگ (Validated)
  void _showAddTransactionDialog(BuildContext context) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    bool isCreditEntry = false; // Defualt: Debit (ادھار)

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'نیا اندراج کریں (Add Entry)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: ChoiceChip(
                            label: const Center(child: Text('ادھار (Debit)')),
                            selected: !isCreditEntry,
                            selectedColor: Colors.red.shade100,
                            onSelected: (val) {
                              setDialogState(() => isCreditEntry = false);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: ChoiceChip(
                            label: const Center(child: Text('وصولی (Credit)')),
                            selected: isCreditEntry,
                            selectedColor: Colors.green.shade100,
                            onSelected: (val) {
                              setDialogState(() => isCreditEntry = true);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'تفصیل (Description)',
                      hintText: 'مثلاً: آٹا پسائی یا نقد وصولی',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'رقم (Amount)',
                      hintText: 'مثلاً: 500',
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('منسوخ کریں'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final desc = descController.text.trim();
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;

                  // 🛑 Input Validation
                  if (desc.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('برائے مہربانی تفصیل درج کریں')),
                    );
                    return;
                  }
                  if (amt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('برائے مہربانی درست رقم درج کریں')),
                    );
                    return;
                  }

                  final newTransaction = LedgerTransaction(
                    id: '',
                    customerName: widget.customerName,
                    customerPhone: widget.customerPhone,
                    description: desc,
                    amount: amt,
                    isCredit: isCreditEntry,
                    date: DateTime.now(),
                  );

                  Navigator.pop(ctx);

                  final ledgerProvider = context.read<LedgerProvider>();
                  final success = await ledgerProvider.addTransaction(newTransaction);

                  if (mounted && !success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اندراج محفوظ کرنے میں ناکامی ہوئی')),
                    );
                  }
                },
                child: const Text('محفوظ کریں'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 💬 واٹس ایپ میسجنگ (Validated Phone Format)
  Future<void> _sendWhatsAppMessage(
      double totalDebit, double totalCredit, double remainingBalance) async {
    final ledgerProvider = context.read<LedgerProvider>();
    final formattedPhone = ledgerProvider.formatPakistanPhone(widget.customerPhone);

    final String message = '''
*الغفار چکی - کسٹمر کھاتہ اسٹیٹمنٹ*
گاہک کا نام: ${widget.customerName}
تاریخ: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}

کل ادھار: Rs. ${totalDebit.toStringAsFixed(0)}
کل وصولی: Rs. ${totalCredit.toStringAsFixed(0)}
---------------------------
*بقایا واجب الادا رقم: Rs. ${remainingBalance.toStringAsFixed(0)}*
---------------------------
شکریہ! الغفار چکی اینڈ جنرل اسٹور
''';

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('واٹس ایپ ایپلیکیشن کھولنا ممکن نہیں ہے')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ایرر: $e')),
        );
      }
    }
  }

  // 🖨️ پی ڈی ایف رپورٹ (English Labels for Standard PDF Support)
  Future<void> _printLedgerPdf(List<LedgerTransaction> transactions,
      double totalDebit, double totalCredit, double remainingBalance) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Al-Ghafar Chakki & General Store',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Customer Khata Ledger Statement',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer: ${widget.customerName}'),
                    pw.Text('Phone: ${widget.customerPhone}'),
                  ],
                ),
                pw.Text(
                  'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                ),
                pw.SizedBox(height: 15),

                // Table
                pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Description', 'Type', 'Amount (Rs)'],
                  data: transactions.map((t) {
                    return [
                      DateFormat('dd/MM/yy').format(t.date),
                      t.description,
                      t.isCredit ? 'Credit (Received)' : 'Debit (Added)',
                      t.amount.toStringAsFixed(0),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),

                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Debit: Rs. ${totalDebit.toStringAsFixed(0)}'),
                    pw.Text('Total Credit: Rs. ${totalCredit.toStringAsFixed(0)}'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.grey200,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Net Remaining Balance:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Rs. ${remainingBalance.toStringAsFixed(0)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ledger_${widget.customerName}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgerProvider = context.read<LedgerProvider>();

    return StreamBuilder<List<LedgerTransaction>>(
      stream: ledgerProvider.getCustomerLedgerStream(widget.customerPhone),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];

        double totalDebit = transactions
            .where((t) => !t.isCredit)
            .fold(0.0, (sum, t) => sum + t.amount);

        double totalCredit = transactions
            .where((t) => t.isCredit)
            .fold(0.0, (sum, t) => sum + t.amount);

        double remainingBalance = totalDebit - totalCredit;

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.customerName} - کھاتہ'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'پرنٹ / PDF',
                onPressed: () => _printLedgerPdf(
                  transactions,
                  totalDebit,
                  totalCredit,
                  remainingBalance,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chat_rounded),
                tooltip: 'واٹس ایپ اسٹیٹمنٹ',
                onPressed: () => _sendWhatsAppMessage(
                  totalDebit,
                  totalCredit,
                  remainingBalance,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 📊 بیلنس سمری کارڈ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryTile(
                      'کل ادھار',
                      'Rs. ${totalDebit.toStringAsFixed(0)}',
                      Colors.red.shade700,
                    ),
                    _buildSummaryTile(
                      'کل وصولی',
                      'Rs. ${totalCredit.toStringAsFixed(0)}',
                      Colors.green.shade700,
                    ),
                    _buildSummaryTile(
                      'بقایا کھاتہ',
                      'Rs. ${remainingBalance.toStringAsFixed(0)}',
                      AppColors.primary,
                      isBold: true,
                    ),
                  ],
                ),
              ),

              // 📜 ٹرانزیکشن ہسٹری
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : transactions.isEmpty
                        ? const Center(
                            child: Text(
                              'ابھی تک اس کسٹمر کا کوئی اندراج موجود نہیں ہے',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final item = transactions[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: item.isCredit
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Icon(
                                      item.isCredit
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: item.isCredit
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                  title: Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('dd MMM yyyy - hh:mm a')
                                        .format(item.date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(
                                    '${item.isCredit ? "-" : "+"} Rs. ${item.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: item.isCredit
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddTransactionDialog(context),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('نیا اندراج'),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTile(
    String label,
    String amount,
    Color color, {
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}