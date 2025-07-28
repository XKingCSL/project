import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class DeliveredProductReportPage extends StatefulWidget {
  const DeliveredProductReportPage({super.key});

  @override
  State<DeliveredProductReportPage> createState() =>
      _DeliveredProductReportPageState();
}

class _DeliveredProductReportPageState
    extends State<DeliveredProductReportPage> {
  bool _isAscending = false;
  List<Map<String, dynamic>> _cachedData = [];

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  Future<List<Map<String, dynamic>>> _fetchDeliveredProductSummary() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Deliveries')
          .where('deliveryStatus', isEqualTo: 'delivered');

      final snapshot = await query.get();

      final Map<String, Map<String, dynamic>> productSummary = {};
      for (var doc in snapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc['items'] ?? []);
        for (var item in items) {
          final productName =
              item['productName']?.toString() ?? 'ບໍ່ມີຊື່ສິນຄ້າ';
          int qty = 0;
          if (item['quantity'] != null) {
            if (item['quantity'] is int) {
              qty = item['quantity'] as int;
            } else if (item['quantity'] is double) {
              qty = (item['quantity'] as double).toInt();
            } else if (item['quantity'] is String) {
              qty = int.tryParse(item['quantity'] as String) ?? 0;
            }
          }
          final unit = item['unit']?.toString() ?? '';
          double price = 0;
          if (item['price'] != null) {
            if (item['price'] is int) {
              price = (item['price'] as int).toDouble();
            } else if (item['price'] is double) {
              price = item['price'] as double;
            } else if (item['price'] is String) {
              price = double.tryParse(item['price'] as String) ?? 0;
            }
          }
          double totalPrice = price * qty;

          if (!productSummary.containsKey(productName)) {
            productSummary[productName] = {
              'productName': productName,
              'quantity': 0,
              'unit': unit,
              'totalPrice': 0.0,
            };
          }
          productSummary[productName]!['quantity'] += qty;
          productSummary[productName]!['totalPrice'] += totalPrice;
        }
      }

      final list = productSummary.values.toList();
      list.sort(
        (a, b) => _isAscending
            ? (a['totalPrice'] as double).compareTo(b['totalPrice'] as double)
            : (b['totalPrice'] as double).compareTo(a['totalPrice'] as double),
      );

      _cachedData = list;
      return list;
    } catch (e) {
      debugPrint('Error fetching delivered product summary: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _getSortedData() {
    if (_cachedData.isEmpty) return [];

    final sortedData = List<Map<String, dynamic>>.from(_cachedData);
    sortedData.sort(
      (a, b) => _isAscending
          ? (a['totalPrice'] as double).compareTo(b['totalPrice'] as double)
          : (b['totalPrice'] as double).compareTo(a['totalPrice'] as double),
    );
    return sortedData;
  }

  Future<void> _generateDeliveredProductPdf(
    List<Map<String, dynamic>> data,
  ) async {
    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
      final laoFont = pw.Font.ttf(fontData);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.DefaultTextStyle(
            style: pw.TextStyle(font: laoFont, fontSize: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ລາຍງານສິນຄ້າທີ່ຈັດສົ່ງ',
                  style: pw.TextStyle(fontSize: 20, font: laoFont),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'ຈຳນວນສິນຄ້າທີ່ຈັດສົ່ງທັງໝົດ: ${data.length} ລາຍການ',
                  style: pw.TextStyle(font: laoFont),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    font: laoFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(font: laoFont),
                  headers: ['ຊື່ສິນຄ້າ', 'ຈຳນວນ', 'ຫົວໜ່ວຍ'],
                  data: data
                      .map(
                        (p) => [
                          p['productName']?.toString() ?? 'ບໍ່ມີຊື່ສິນຄ້າ',
                          p['quantity']?.toString() ?? '0',
                          p['unit']?.toString() ?? '',
                        ],
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການສົ່ງອອກ PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານສິນຄ້າທີ່ຈັດສົ່ງ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final currentContext = context;
              final data = await _fetchDeliveredProductSummary();
              if (data.isNotEmpty && mounted && currentContext.mounted) {
                await _generateDeliveredProductPdf(data);
              } else if (mounted && currentContext.mounted) {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  const SnackBar(content: Text('ບໍ່ມີຂໍ້ມູນສຳລັບ Export PDF')),
                );
              }
            },
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchDeliveredProductSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'ເກີດຂໍ້ຜິດພາດ: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('ລອງໃໝ່'),
                  ),
                ],
              ),
            );
          }

          final data = _getSortedData();
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'ບໍ່ມີຂໍ້ມູນສິນຄ້າທີ່ຈັດສົ່ງແລ້ວ',
                    style: TextStyle(fontSize: 24),
                  ),
                ],
              ),
            );
          }

          final total = data.length;
          final start = _currentPage * _rowsPerPage;
          final end = (start + _rowsPerPage) > total
              ? total
              : (start + _rowsPerPage);
          final pageData = data.sublist(start, end);
          return Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ຈຳນວນສິນຄ້າທີ່ຈັດສົ່ງທັງໝົດ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          '$total ລາຍການ',
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isAscending = !_isAscending;
                        });
                      },
                      icon: Icon(
                        _isAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        _isAscending
                            ? 'ຈຳນວນສິນຄ້າໜ້ອຍຫາຫຼາຍ'
                            : 'ຈຳນວນສິນຄ້າຫຼາຍຫາໜ້ອຍ',
                        style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: pageData.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = pageData[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.inventory_2,
                          color: Colors.deepPurple,
                        ),
                        title: Text(
                          p['productName']?.toString() ?? 'ບໍ່ມີຊື່ສິນຄ້າ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'ຈຳນວນ: ${p['quantity']} ${p['unit']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          '${(p['totalPrice'] as double).toStringAsFixed(0)} ກີບ',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
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
                                      style: const TextStyle(fontSize: 14),
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
    );
  }
}
