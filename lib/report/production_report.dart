import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project/dashboard/product.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class ProductionReportPage extends StatefulWidget {
  const ProductionReportPage({super.key});

  @override
  State<ProductionReportPage> createState() => _ProductionReportPageState();
}

class _ProductionReportPageState extends State<ProductionReportPage> {
  final CollectionReference _productCollection = FirebaseFirestore.instance
      .collection('Products');
  Product? selectedProduct;

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
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

  Stream<List<Map<String, dynamic>>> getProductHistory() {
    if (_startDate == null || _endDate == null) {
      return Stream.value([]);
    }

    try {
      Query query = FirebaseFirestore.instance.collection('Production_Report');

      // Filter by product if one is selected nai trn search
      if (selectedProduct != null) {
        query = query.where('productId', isEqualTo: selectedProduct!.productId);
      }

      // Always filter by date range and sort by newest first
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
          )
          .orderBy('createdAt', descending: true);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'id': doc.id,
            'type': data.containsKey('quantity') ? 'production' : 'history',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error in getProductHistory: $e');
      return Stream.value([]);
    }
  }

  Future<void> _generateProductionReportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
    final laoFont = pw.Font.ttf(fontData);

    Query query = FirebaseFirestore.instance.collection('Production_Report');

    if (selectedProduct != null) {
      query = query.where('productId', isEqualTo: selectedProduct!.productId);
    }
    query = query
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!))
        .orderBy('createdAt', descending: true);

    final reportSnapshot = await query.get();
    final records = reportSnapshot.docs;

    pdf.addPage(
      pw.Page(
        build: (context) => pw.DefaultTextStyle(
          style: pw.TextStyle(font: laoFont, fontSize: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ລາຍງານ​ການ​ຜະ​ລິດ', style: pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text(
                'ຊ່ວງວັນທີ: '
                '${DateFormat('dd/MM/yyyy').format(_startDate!)} ຫາ '
                '${DateFormat('dd/MM/yyyy').format(_endDate!)}',
              ),
              if (selectedProduct != null)
                pw.Text('ສິນຄ້າ: ${selectedProduct!.productName}'),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: [
                  'ວັນທີ',
                  'ຊື່ສິນຄ້າ',
                  'ລາຍການ',
                  'ລາຍລະອຽດ',
                  'ຜູ້ດຳເນີນການ',
                ],
                data: records.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['createdAt'] as Timestamp;
                  final date = DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(timestamp.toDate());
                  final productName = data['productName'] ?? '-';
                  final user = data['createdBy'] ?? '-';
                  String action = '';
                  String details = '';

                  if (data.containsKey('quantity')) {
                    action = 'ເພີ່ມການຜະລິດ';
                    details = '${data['quantity']} ${data['unit']}';
                  } else {
                    switch (data['action']) {
                      case 'create':
                        action = 'ສ້າງສິນຄ້າໃໝ່';
                        details = data['changes'] ?? '';
                        break;
                      case 'edit':
                        action = 'ແກ້ໄຂຂໍ້ມູນ';
                        details = data['changes'] ?? '';
                        break;
                      case 'delete':
                        action = 'ລຶບສິນຄ້າ';
                        details = data['changes'] ?? '';
                        break;
                      default:
                        action = 'ອັບເດດ';
                        details = data['changes'] ?? '';
                    }
                  }
                  return [date, productName, action, details, user];
                }).toList(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(70),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(50),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(60),
                },
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  String _getActionText(Map<String, dynamic> record) {
    if (record['type'] == 'production') {
      return 'ເພີ່ມການຜະລິດ: ${record['quantity']} ${record['unit']}';
    }

    switch (record['action']) {
      case 'create':
        return 'ສ້າງສິນຄ້າໃໝ່';
      case 'edit':
        return 'ແກ້ໄຂຂໍ້ມູນສິນຄ້າ';
      case 'delete':
        return 'ລຶບສິນຄ້າ';
      default:
        return 'ອັບເດດຂໍ້ມູນ';
    }
  }

  IconData _getActionIcon(Map<String, dynamic> record) {
    if (record['type'] == 'production') {
      return Icons.add_business;
    }
    switch (record['action']) {
      case 'create':
        return Icons.add_circle_outline;
      case 'edit':
        return Icons.edit_note;
      case 'delete':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  Color _getActionIconColor(Map<String, dynamic> record) {
    if (record['type'] == 'production') {
      return Colors.green;
    }
    switch (record['action']) {
      case 'create':
        return Colors.blue;
      case 'edit':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານ​ການ​ຜະ​ລິດ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateProductionReportPdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _productCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final products = snapshot.data!.docs
                        .map((doc) => Product.fromDocument(doc))
                        .toList();

                    return Autocomplete<Product>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return products;
                        }
                        return products.where(
                          (Product product) => product.productName
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()),
                        );
                      },
                      displayStringForOption: (Product option) =>
                          option.productName,
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            if (selectedProduct != null) {
                              controller.text = selectedProduct!.productName;
                            }
                            return StatefulBuilder(
                              builder: (context, setFieldState) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'ຄົ້ນຫາສິນຄ້າ',
                                    labelStyle: const TextStyle(fontSize: 20),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: controller.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setFieldState(() {
                                                controller.clear();
                                              });
                                              setState(() {
                                                selectedProduct = null;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (_) => setFieldState(() {}),
                                );
                              },
                            );
                          },
                      onSelected: (Product selection) {
                        setState(() {
                          selectedProduct = selection;
                        });
                      },
                      initialValue: selectedProduct != null
                          ? TextEditingValue(text: selectedProduct!.productName)
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
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
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getProductHistory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('ເກີດຂໍ້ຜິດພາດ: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data!;
                if (records.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນການຜະລິດ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                final total = records.length;
                final start = _currentPage * _rowsPerPage;
                final end = (start + _rowsPerPage) > total
                    ? total
                    : (start + _rowsPerPage);
                final pageRecords = records.sublist(start, end);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageRecords.length,
                        itemBuilder: (context, index) {
                          final record = pageRecords[index];
                          final timestamp = record['createdAt'] as Timestamp;
                          final date = timestamp.toDate();
                          final action = _getActionText(record);
                          final title =
                              record['productName'] as String? ??
                              'ບໍ່ມີຊື່ສິນຄ້າ';

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                _getActionIcon(record),
                                color: _getActionIconColor(record),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: DefaultTextStyle.merge(
                                style: const TextStyle(fontSize: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (record['type'] == 'production')
                                      Text(
                                        action,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else if (record['action'] == 'edit')
                                      Text(
                                        action,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (record['changes'] != null)
                                      Text(
                                        'ການປ່ຽນແປງ: ${record['changes']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (record['note'] != null)
                                      Text(
                                        'ໝາຍເຫດ: ${record['note']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text(
                                      'ວັນທີ: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'ຜູ້ດຳເນີນການ: ${record['createdBy']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
