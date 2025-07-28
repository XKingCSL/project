import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class CustomerReportPage extends StatefulWidget {
  const CustomerReportPage({super.key});

  @override
  State<CustomerReportPage> createState() => _CustomerReportPageState();
}

class _CustomerReportPageState extends State<CustomerReportPage> {
  final CollectionReference _customerCollection = FirebaseFirestore.instance
      .collection('Customers');
  final CollectionReference _orderCollection = FirebaseFirestore.instance
      .collection('Orders');

  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _customerReports = [];
  int? _expandedIndex; // Track which ExpansionTile is open

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
    _loadCustomerReports();
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
      _loadCustomerReports();
    }
  }

  Future<void> _loadCustomerReports() async {
    setState(() {
      _isLoading = true;
    });
    final customersSnapshot = await _customerCollection.get();
    final customers = customersSnapshot.docs;
    final List<Map<String, dynamic>> reports = [];
    for (final customerDoc in customers) {
      final customerId = customerDoc.id;
      final customerData = customerDoc.data() as Map<String, dynamic>? ?? {};

      Query orderQuery = _orderCollection.where(
        'customerId',
        isEqualTo: customerId,
      );
      if (_startDate != null) {
        orderQuery = orderQuery.where(
          'orderDate',
          isGreaterThanOrEqualTo: _startDate,
        );
      }
      if (_endDate != null) {
        orderQuery = orderQuery.where(
          'orderDate',
          isLessThanOrEqualTo: _endDate,
        );
      }
      QuerySnapshot? orderSnapshot;
      try {
        orderSnapshot = await orderQuery.get();
      } catch (e) {
        orderSnapshot = null;
      }
      final orders = orderSnapshot?.docs ?? [];
      double totalPurchase = 0;
      DateTime? lastPurchaseDate;
      int validOrderCount = 0;
      for (final order in orders) {
        final data = order.data() as Map<String, dynamic>? ?? {};
        if ((data['deliveryStatus'] ?? '').toString().toLowerCase() ==
            'cancelled') {
          continue;
        }
        totalPurchase += (data['totalPrice'] ?? 0).toDouble();
        validOrderCount++;
        final orderDate = (data['orderDate'] is Timestamp)
            ? (data['orderDate'] as Timestamp).toDate()
            : null;
        if (orderDate != null &&
            (lastPurchaseDate == null || orderDate.isAfter(lastPurchaseDate))) {
          lastPurchaseDate = orderDate;
        }
      }

      reports.add({
        'customerId': customerId,
        'customerName': customerData['customerName'] ?? '',
        'customerPhone': customerData['customerPhone'] ?? '',
        'customerAddress': customerData['customerAddress'] ?? '',
        'totalPurchase': totalPurchase,
        'orderCount': validOrderCount,
        'lastPurchaseDate': lastPurchaseDate,
      });
    }
    setState(() {
      _customerReports = reports;
      _isLoading = false;
    });
  }

  Future<void> _generateCustomerPdf(Map<String, dynamic> c) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
    final laoFont = pw.Font.ttf(fontData);
    pdf.addPage(
      pw.Page(
        build: (context) => pw.DefaultTextStyle(
          style: pw.TextStyle(font: laoFont, fontSize: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${c['customerId']} - ${c['customerName']}',
                style: pw.TextStyle(
                  font: laoFont,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'ເບີໂທ: ${c['customerPhone'] ?? '-'}',
                style: pw.TextStyle(font: laoFont),
              ),
              pw.Text(
                'ທີ່ຢູ່: ${c['customerAddress'] ?? '-'}',
                style: pw.TextStyle(font: laoFont),
              ),
              pw.Text(
                'ຍອດຊື້ລວມ: ${(c['totalPurchase'] ?? 0).toStringAsFixed(0)} ກີບ',
                style: pw.TextStyle(
                  font: laoFont,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'ຈຳນວນຄຳສັ່ງຊື້: ${c['orderCount'] ?? 0}',
                style: pw.TextStyle(font: laoFont),
              ),
              pw.Text(
                'ສັ່ງຊື້ລ່າສຸດ: ${c['lastPurchaseDate'] != null ? DateFormat('yyyy-MM-dd').format(c['lastPurchaseDate']) : '-'}',
                style: pw.TextStyle(font: laoFont),
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
    final filteredReports = _customerReports.where((c) {
      final search = _search.toLowerCase();
      return c['customerId'].toString().toLowerCase().contains(search) ||
          c['customerName'].toString().toLowerCase().contains(search);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານລູກຄ້າ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () {
              if (_expandedIndex != null &&
                  _expandedIndex! < filteredReports.length) {
                _generateCustomerPdf(filteredReports[_expandedIndex!]);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ກະລຸນາເປີດລາຍການລູກຄ້າ')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ຄົ້ນຫາລູກຄ້າ',
                labelStyle: const TextStyle(fontSize: 20),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _search = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredReports.isEmpty
                ? const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນລູກຄ້າ',
                      style: TextStyle(fontSize: 24),
                    ),
                  )
                : (() {
                    final total = filteredReports.length;
                    final start = _currentPage * _rowsPerPage;
                    final end = (start + _rowsPerPage) > total
                        ? total
                        : (start + _rowsPerPage);
                    final pageReports = filteredReports.sublist(start, end);
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            itemCount: pageReports.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final c = pageReports[i];
                              final globalIndex = start + i;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 1,
                                  ),
                                  initiallyExpanded:
                                      _expandedIndex == globalIndex,
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      _expandedIndex = expanded
                                          ? globalIndex
                                          : null;
                                    });
                                  },
                                  title: Text(
                                    '${c['customerId']} - ${c['customerName']}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  leading: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                  children: [
                                    ListTile(
                                      leading: const SizedBox(width: 47),
                                      contentPadding: const EdgeInsets.only(
                                        left: 0,
                                        right: 16,
                                      ),
                                      title: Text(
                                        'ເບີໂທ: ${c['customerPhone'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const SizedBox(width: 47),
                                      contentPadding: const EdgeInsets.only(
                                        left: 0,
                                        right: 16,
                                      ),
                                      title: Text(
                                        'ທີ່ຢູ່: ${c['customerAddress'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const SizedBox(width: 47),
                                      contentPadding: const EdgeInsets.only(
                                        left: 0,
                                        right: 18,
                                      ),
                                      title: Text(
                                        'ຍອດຊື້ລວມ: ${(c['totalPurchase'] ?? 0).toStringAsFixed(0)} ກີບ',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const SizedBox(width: 47),
                                      contentPadding: const EdgeInsets.only(
                                        left: 0,
                                        right: 18,
                                      ),
                                      title: Text(
                                        'ຈຳນວນຄຳສັ່ງຊື້: ${c['orderCount'] ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const SizedBox(width: 47),
                                      contentPadding: const EdgeInsets.only(
                                        left: 0,
                                        right: 18,
                                      ),
                                      title: Text(
                                        'ສັ່ງຊື້ລ່າສຸດ: ${c['lastPurchaseDate'] != null ? DateFormat('yyyy-MM-dd').format(c['lastPurchaseDate']) : '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
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
                  })(),
          ),
        ],
      ),
    );
  }
}
