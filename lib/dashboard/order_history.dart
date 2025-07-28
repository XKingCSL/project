import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  // สำหรับ Pagination
  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [5, 10, 20, 50];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ປະຫວັດການຂາຍ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Orders')
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('ບໍ່ມີປະຫວັດການຂາຍ', style: TextStyle(fontSize: 24)),
            );
          }
          final orders = snapshot.data!.docs;
          final total = orders.length;
          final start = _currentPage * _rowsPerPage;
          final end = ((start + _rowsPerPage) > total)
              ? total
              : (start + _rowsPerPage);
          final pageOrders = orders.sublist(start, end);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: pageOrders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = pageOrders[i];
                    final data = doc.data() as Map<String, dynamic>;
                    // ...existing code...
                    return ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        '${data['orderId'] ?? ''} - ${data['customerName'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'ວັນທີ: ${data['orderDate']?.toDate().toString().substring(0, 16) ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: false,
                      trailing: Text(
                        '${data['totalPrice']?.toStringAsFixed(0) ?? '0'} ກີບ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text(
                                'ລາຍລະອຽດການຂາຍ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ລະຫັດການຂາຍ: ${data['orderId'] ?? ''}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    Text(
                                      'ລູກຄ້າ: ${data['customerName'] ?? ''}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    Text(
                                      'ເບີໂທ: ${data['customerPhone'] ?? ''}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    Text(
                                      'ທີ່ຢູ່: ${data['customerAddress'] ?? ''}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    Text(
                                      'ວັນທີ: ${data['orderDate']?.toDate().toString().substring(0, 16) ?? ''}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'ລາຍການສິນຄ້າ:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    ...((data['items'] as List<dynamic>? ?? []).map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          '- ${item['productName']} x${item['quantity']} (${(item['price'] % 1 == 0 ? item['price'].toInt() : item['price'])} ກີບ)',
                                          style: const TextStyle(fontSize: 17),
                                        ),
                                      ),
                                    )),
                                    const SizedBox(height: 16),
                                    Text(
                                      'ລາຄາລວມ: ${data['totalPrice']?.toStringAsFixed(0) ?? '0'} ກີບ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      'ສະຖານະການຈ່າຍເງິນ: ${data['paymentStatus'] == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງບໍ່ໄດ້ຈ່າຍ'}',
                                      style: const TextStyle(fontSize: 17),
                                    ),
                                    if ((data['note'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          'ໝາຍເຫດ: ${data['note']}',
                                          style: const TextStyle(fontSize: 17),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'ປິດ',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              contentPadding: const EdgeInsets.fromLTRB(
                                24,
                                20,
                                24,
                                10,
                              ),
                            );
                          },
                        );
                      },
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
