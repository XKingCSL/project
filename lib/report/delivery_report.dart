import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'delivered_product_report.dart';

class DeliveryReportPage extends StatefulWidget {
  const DeliveryReportPage({super.key});

  @override
  State<DeliveryReportPage> createState() => _DeliveryReportPageState();
}

class _DeliveryReportPageState extends State<DeliveryReportPage> {
  final CollectionReference _deliveryCollection = FirebaseFirestore.instance
      .collection('Deliveries');

  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';

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
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _deliveryCollection;
      if (_startDate != null) {
        query = query.where(
          'deliveryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
        );
      }
      if (_endDate != null) {
        query = query.where(
          'deliveryDate',
          isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
        );
      }
      query = query.orderBy('deliveryDate', descending: true);
      final snapshot = await query.get();
      final deliveries = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          })
          .where(
            (d) =>
                d['deliveryStatus'] == 'delivered' ||
                d['deliveryStatus'] == 'cancelled',
          )
          .toList();

      setState(() {
        _deliveries = deliveries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e')));
      }
    }
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
      _loadDeliveries();
    }
  }

  Map<String, dynamic> _getStatistics() {
    final total = _deliveries.length;
    final delivered = _deliveries
        .where((d) => d['deliveryStatus'] == 'delivered')
        .length;
    final cancelled = _deliveries
        .where((d) => d['deliveryStatus'] == 'cancelled')
        .length;

    return {'total': total, 'delivered': delivered, 'cancelled': cancelled};
  }

  Future<void> _generateDeliveryReportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
    final laoFont = pw.Font.ttf(fontData);

    final stats = _getStatistics();
    final displayedDeliveries = _selectedStatus == 'all'
        ? _deliveries
        : _deliveries
              .where((d) => d['deliveryStatus'] == _selectedStatus)
              .toList();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: laoFont, fontSize: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ລາຍງານການຈັດສົ່ງ',
                  style: pw.TextStyle(
                    font: laoFont,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (_startDate != null && _endDate != null)
                  pw.Text(
                    'ຊ່ວງວັນທີ: ${DateFormat('dd/MM/yyyy').format(_startDate!)} ຫາ ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                    style: pw.TextStyle(font: laoFont, fontSize: 16),
                  ),
                pw.Text(
                  'ສະຖານະ: ${_getStatusText(_selectedStatus)}',
                  style: pw.TextStyle(font: laoFont, fontSize: 16),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ທັງໝົດ: ${stats['total']}',
                      style: pw.TextStyle(font: laoFont),
                    ),
                    pw.Text(
                      'ຈັດສົ່ງແລ້ວ: ${stats['delivered']}',
                      style: pw.TextStyle(font: laoFont),
                    ),
                    pw.Text(
                      'ຍົກເລີກ: ${stats['cancelled']}',
                      style: pw.TextStyle(font: laoFont),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    font: laoFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(font: laoFont),
                  headers: [
                    'ລະຫັດຄຳສັ່ງຊື້',
                    'ລູກຄ້າ',
                    'ວັນທີ',
                    'ສະຖານະ',
                    'ລາຄາລວມ',
                    'ຜູ້ດຳເນີນການ',
                  ],
                  data: displayedDeliveries.map((delivery) {
                    final deliveryDate = (delivery['deliveryDate'] as Timestamp)
                        .toDate();
                    final items = List<Map<String, dynamic>>.from(
                      delivery['items'] ?? [],
                    );
                    double totalPrice = items.fold<double>(
                      0,
                      (total, item) =>
                          total +
                          ((item['price'] ?? 0) * (item['quantity'] ?? 0)),
                    );
                    final adminName = delivery['adminName'] ?? '';
                    return [
                      delivery['orderId'] ?? '-',
                      delivery['customerName'] ?? '-',
                      DateFormat('dd/MM/yyyy').format(deliveryDate),
                      _getStatusText(delivery['deliveryStatus']),
                      '${totalPrice.toStringAsFixed(0)} ກີບ',
                      adminName,
                    ];
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStatistics();

    final displayedDeliveries = _selectedStatus == 'all'
        ? _deliveries
        : _deliveries
              .where((d) => d['deliveryStatus'] == _selectedStatus)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານການຈັດສົ່ງ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateDeliveryReportPdf,
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedStatus = 'all'),
                      child: _buildStatCard(
                        'ທັງໝົດ',
                        stats['total'].toString(),
                        Colors.blue,
                        Icons.local_shipping,
                        _selectedStatus == 'all',
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedStatus = 'delivered'),
                      child: _buildStatCard(
                        'ຈັດສົ່ງແລ້ວ',
                        stats['delivered'].toString(),
                        Colors.green,
                        Icons.check_circle,
                        _selectedStatus == 'delivered',
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedStatus = 'cancelled'),
                      child: _buildStatCard(
                        'ຍົກເລີກ',
                        stats['cancelled'].toString(),
                        Colors.red,
                        Icons.cancel,
                        _selectedStatus == 'cancelled',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedDeliveries.isEmpty
                ? const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນການຈັດສົ່ງ',
                      style: TextStyle(fontSize: 24),
                    ),
                  )
                : (() {
                    final total = displayedDeliveries.length;
                    final start = _currentPage * _rowsPerPage;
                    final end = (start + _rowsPerPage) > total
                        ? total
                        : (start + _rowsPerPage);
                    final pageDeliveries = displayedDeliveries.sublist(
                      start,
                      end,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: pageDeliveries.length,
                            itemBuilder: (context, index) {
                              final delivery = pageDeliveries[index];
                              final deliveryDate =
                                  (delivery['deliveryDate'] as Timestamp)
                                      .toDate();
                              final status =
                                  delivery['deliveryStatus'] as String;
                              final items = List<Map<String, dynamic>>.from(
                                delivery['items'] ?? [],
                              );
                              double totalPrice = items.fold<double>(
                                0,
                                (total, item) =>
                                    total +
                                    ((item['price'] ?? 0) *
                                        (item['quantity'] ?? 0)),
                              );
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ExpansionTile(
                                  title: Text(
                                    'ລະຫັດຄຳສັ່ງຊື້: ${delivery['orderId']}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ລູກຄ້າ: ${delivery['customerName']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'ວັນທີຈັດສົ່ງ: ${DateFormat('yyyy-MM-dd HH:mm').format(deliveryDate)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Text(
                                            'ສະຖານະ: ',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: status == 'delivered'
                                                  ? Colors.green
                                                  : status == 'cancelled'
                                                  ? Colors.red
                                                  : status == 'in_progress'
                                                  ? Colors.orange
                                                  : Colors.grey,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(status),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ທີ່ຢູ່: ${delivery['customerAddress']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'ເບີໂທ: ${delivery['customerPhone']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Text(
                                            'ລາຍການສິນຄ້າ:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          ...items.map(
                                            (item) => Text(
                                              '- ${item['productName']} x${item['quantity']} ${item['unit']}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (items.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 187,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'ລາຄາລວມ: '
                                                    '${totalPrice.toStringAsFixed(0)} ກີບ',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  if (delivery['adminName']
                                                          ?.isNotEmpty ==
                                                      true)
                                                    Text(
                                                      'ຜູ້ດຳເນີນການ: ${delivery['adminName']}',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          if (delivery['note']?.isNotEmpty ==
                                              true) ...[
                                            Text(
                                              'ໝາຍເຫດ: ${delivery['note']}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DeliveredProductReportPage(),
              ),
            );
          },
          icon: const Icon(Icons.inventory_2),
          label: const Text(
            'ຈຳນວນສິນຄ້າທີ່ຈັດສົ່ງແລ້ວ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Color(0xFF6C4AB6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
    bool isSelected,
  ) {
    return Card(
      color: color,
      shape: isSelected
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.blueGrey, width: 6.0),
              borderRadius: BorderRadius.circular(12.0),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'delivered':
        return 'ຈັດສົ່ງແລ້ວ';
      case 'cancelled':
        return 'ຍົກເລີກ';
      case 'all':
        return 'ທັງໝົດ';
      default:
        return '';
    }
  }
}
