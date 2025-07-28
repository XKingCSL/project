import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class StocksReportPage extends StatefulWidget {
  const StocksReportPage({super.key});

  @override
  State<StocksReportPage> createState() => _StocksReportPageState();
}

class _StocksReportPageState extends State<StocksReportPage> {
  bool _isAscending = true;

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generateStocksReportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
    final laoFont = pw.Font.ttf(fontData);
    final stocksSnapshot = await FirebaseFirestore.instance
        .collection('Products')
        .get();
    final stocks = stocksSnapshot.docs;

    // Sort the stocks for PDF
    final sortedStocks = stocks.toList()
      ..sort((a, b) {
        final stockA = (a.data()['stock'] ?? 0) as int;
        final stockB = (b.data()['stock'] ?? 0) as int;
        return _isAscending
            ? stockA.compareTo(stockB)
            : stockB.compareTo(stockA);
      });

    pdf.addPage(
      pw.Page(
        build: (context) => pw.DefaultTextStyle(
          style: pw.TextStyle(font: laoFont, fontSize: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ລາຍງານສິນຄ້າ', style: pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text(
                'ການຈັດລຽງ: ${_isAscending ? "ຈຳນວນໜ້ອຍຫາຫຼາຍ" : "ຈຳນວນຫຼາຍຫາໜ້ອຍ"}',
                style: pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: [
                  'ລະຫັດ',
                  'ຊື່ສິນຄ້າ',
                  'ຈຳນວນ',
                  'ຫົວໜ່ວຍ',
                  'ລາຄາ',
                  'ຄຳອະທິບາຍ',
                ],
                data: sortedStocks.map((doc) {
                  final data = doc.data();
                  return [
                    data['productId'] ?? '-',
                    data['productName'] ?? '-',
                    data['stock']?.toString() ?? '0',
                    data['unit'] ?? '-',
                    '${data['price']?.toStringAsFixed(0) ?? '0'} ກີບ',
                    data['description'] ?? '-',
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  List<QueryDocumentSnapshot> _sortStocks(List<QueryDocumentSnapshot> stocks) {
    return stocks..sort((a, b) {
      final stockA = (a.data() as Map<String, dynamic>)['stock'] ?? 0;
      final stockB = (b.data() as Map<String, dynamic>)['stock'] ?? 0;
      return _isAscending ? stockA.compareTo(stockB) : stockB.compareTo(stockA);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານສິນຄ້າ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateStocksReportPdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນສິນຄ້າ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                // Sort the stocks
                final stocks = _sortStocks(snapshot.data!.docs);

                final total = stocks.length;
                final start = _currentPage * _rowsPerPage;
                final end = (start + _rowsPerPage) > total
                    ? total
                    : (start + _rowsPerPage);
                final pageStocks = stocks.sublist(start, end);

                return Column(
                  children: [
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ຈຳນວນສິນຄ້າທັງໝົດ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              Text(
                                '${stocks.length} ລາຍການ',
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
                                  ? 'ຈຳນວນສິນຄ້າໃນ Stock ໜ້ອຍຫາຫຼາຍ'
                                  : 'ຈຳນວນສິນຄ້າໃນ Stock ຫຼາຍຫາໜ້ອຍ',
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
                        itemCount: pageStocks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final data =
                              pageStocks[i].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(
                              Icons.inventory,
                              color: Colors.deepPurple,
                            ),
                            title: Text(
                              'ລະຫັດ: ${data['productId'] ?? '-'}\n'
                              'ຊື່ສິນຄ້າ: ${data['productName'] ?? '-'}\n'
                              'ຈຳນວນ: ${data['stock']?.toString() ?? '0'} ${data['unit'] ?? ''}\n'
                              'ຄຳອະທິບາຍ: ${data['description'] ?? '-'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              '${data['price']?.toStringAsFixed(0) ?? '0'} ກີບ',
                              style: const TextStyle(
                                fontSize: 18,
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
