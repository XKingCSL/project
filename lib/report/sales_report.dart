import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
      now.day,
    );
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end.add(
          const Duration(hours: 23, minutes: 59, seconds: 59),
        );
      });
    }
  }

  Future<void> _generateSalesReportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
    final laoFont = pw.Font.ttf(fontData);
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('Deliveries')
        .where('deliveryStatus', isEqualTo: 'delivered')
        .where('paymentStatus', isEqualTo: 'paid')
        .where('confirmedAt', isGreaterThanOrEqualTo: _startDate)
        .where('confirmedAt', isLessThanOrEqualTo: _endDate)
        .get();
    final orders = ordersSnapshot.docs;
    double total = 0;
    pdf.addPage(
      pw.Page(
        build: (context) => pw.DefaultTextStyle(
          style: pw.TextStyle(font: laoFont, fontSize: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ລາຍງານຍອດຂາຍ', style: pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text(
                'ຊ່ວງວັນທີ: '
                '${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : '-'} ຫາ '
                '${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : '-'}',
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['ວັນທີ', 'ລູກຄ້າ', 'ຈຳນວນ', 'ສະຖານະ', 'ລາຄາລວມ'],
                data: orders.map((doc) {
                  final data = doc.data();
                  final items = List<Map<String, dynamic>>.from(
                    data['items'] ?? [],
                  );
                  final qty = items.fold<int>(
                    0,
                    (sumQty, item) => sumQty + ((item['quantity'] ?? 0) as int),
                  );
                  final price = items.fold<double>(
                    0,
                    (acc, item) =>
                        acc +
                        ((item['price'] ?? 0) as num) *
                            ((item['quantity'] ?? 0) as num),
                  );
                  total += price;
                  return [
                    data['confirmedAt'] != null
                        ? DateFormat(
                            'yyyy-MM-dd',
                          ).format(data['confirmedAt'].toDate())
                        : '-',
                    data['customerName'] ?? '-',
                    qty.toString(),
                    data['paymentStatus'] == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງບໍ່ຈ່າຍ',
                    '${price.toStringAsFixed(0)} ກີບ',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('ຍອດຂາຍລວມ: ${total.toStringAsFixed(0)} ກີບ'),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານຍອດຂາຍ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateSalesReportPdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ຊ່ວງວັນທີ '
                    '${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : '-'}'
                    ' ຫາ '
                    '${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text(
                    'ເລືອກວັນທີ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _pickDateRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Deliveries')
                  .where('deliveryStatus', isEqualTo: 'delivered')
                  .where('paymentStatus', isEqualTo: 'paid')
                  .where('confirmedAt', isGreaterThanOrEqualTo: _startDate)
                  .where('confirmedAt', isLessThanOrEqualTo: _endDate)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນການຂາຍ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }
                final orders = snapshot.data!.docs;
                final total = orders.length;
                final start = _currentPage * _rowsPerPage;
                final end = (start + _rowsPerPage) > total
                    ? total
                    : (start + _rowsPerPage);
                final pageOrders = orders.sublist(start, end);
                return Column(
                  children: [
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ຍອດຂາຍລວມ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          Text(
                            '${orders.fold<double>(0, (sumTotal, doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
                              final price = items.fold<double>(0, (acc, item) => acc + ((item['price'] ?? 0) * (item['quantity'] ?? 0)));
                              return sumTotal + price;
                            }).toStringAsFixed(0)} ກີບ',
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: pageOrders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final data =
                              pageOrders[i].data() as Map<String, dynamic>;
                          final items = List<Map<String, dynamic>>.from(
                            data['items'] ?? [],
                          );
                          final totalPrice = items.fold<double>(
                            0,
                            (acc, item) =>
                                acc +
                                ((item['price'] ?? 0) *
                                    (item['quantity'] ?? 0)),
                          );
                          final totalQty = items.fold<int>(
                            0,
                            (sumQty, item) =>
                                sumQty + ((item['quantity'] ?? 0) as int),
                          );
                          return ListTile(
                            leading: const Icon(
                              Icons.receipt_long,
                              color: Colors.deepPurple,
                            ),
                            title: Text(
                              'ວັນທີ: '
                              '${data['confirmedAt'] != null ? DateFormat('yyyy-MM-dd').format(data['confirmedAt'].toDate()) : '-'}\n'
                              'ລູກຄ້າ: ${data['customerName'] ?? '-'}\n'
                              'ຈຳນວນສິນຄ້າ: '
                              '$totalQty\n'
                              'ສະຖານະ: ${data['paymentStatus'] == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງບໍ່ຈ່າຍ'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              '${totalPrice.toStringAsFixed(0)} ກີບ',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: 4,
                        left: 8,
                        right: 8,
                      ),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Items per page: '),
                              SizedBox(
                                width: 80,
                                height: 50,
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  isExpanded: true,
                                  iconSize: 32,
                                  items: _availableRowsPerPage
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            '$e',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _rowsPerPage = value;
                                        _currentPage = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                              Text('    ${start + 1} - $end of $total  '),
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: end < total
                                    ? () => setState(() => _currentPage++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
