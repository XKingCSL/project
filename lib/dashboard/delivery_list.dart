import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delivery.dart';

class DeliveryListPage extends StatefulWidget {
  const DeliveryListPage({super.key});

  @override
  State<DeliveryListPage> createState() => _DeliveryListPageState();
}

class _DeliveryListPageState extends State<DeliveryListPage> {
  final CollectionReference _deliveryCollection = FirebaseFirestore.instance
      .collection('Deliveries');

  String _selectedStatus = 'all';
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isSelectionMode = false;
  Set<String> _selectedDeliveries = {};
  bool _selectAll = false;

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDeliveries.clear();
        _selectAll = false;
      }
    });
  }

  void _toggleSelectAll(List<Delivery> deliveries) {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedDeliveries = deliveries.map((d) => d.deliveryId).toSet();
      } else {
        _selectedDeliveries.clear();
      }
    });
  }

  void _toggleDeliverySelection(String deliveryId) {
    setState(() {
      if (_selectedDeliveries.contains(deliveryId)) {
        _selectedDeliveries.remove(deliveryId);
        _selectAll = false;
      } else {
        _selectedDeliveries.add(deliveryId);
      }
    });
  }

  Future<void> _deleteSelectedDeliveries() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final deliveryId in _selectedDeliveries) {
        final deliveryDoc = await _deliveryCollection.doc(deliveryId).get();
        final deliveryData = deliveryDoc.data() as Map<String, dynamic>?;
        batch.update(_deliveryCollection.doc(deliveryId), {
          'deliveryStatus': 'cancelled',
        });
        if (deliveryData != null && deliveryData['orderId'] != null) {
          final orderId = deliveryData['orderId'];
          final orderDoc = FirebaseFirestore.instance
              .collection('Orders')
              .doc(orderId);
          batch.delete(orderDoc);

          if (deliveryData.containsKey('items') &&
              deliveryData['items'] is List) {
            for (final item in (deliveryData['items'] as List)) {
              if (item['productId'] != null && item['quantity'] != null) {
                final productDocRef = FirebaseFirestore.instance
                    .collection('Products')
                    .doc(item['productId']);
                batch.update(productDocRef, {
                  'stock': FieldValue.increment(item['quantity'] as num),
                });
              }
            }
          }
        }
      }
      await batch.commit();
      setState(() {
        _isSelectionMode = false;
        _selectedDeliveries.clear();
        _selectAll = false;
      });
      _showSuccessMessage('ຍົກເລີກລາຍການທີ່ເລືອກສຳເລັດ');
    } catch (e) {
      _showErrorMessage('ເກີດຂໍ້ຜິດພາດໃນການຍົກເລີກລາຍການ: $e');
    }
  }

  Stream<List<Delivery>> _getDeliveries() {
    return _deliveryCollection
        .orderBy('deliveryDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Delivery.fromDocument(doc)).toList(),
        );
  }

  Future<void> _updateDeliveryStatus(
    String deliveryId,
    String newStatus,
  ) async {
    try {
      await _deliveryCollection.doc(deliveryId).update({
        'deliveryStatus': newStatus,
        if (newStatus == 'delivered') 'confirmedAt': Timestamp.now(),
      });

      _showSuccessMessage('ອັບເດດສະຖານະສຳເລັດ');
    } catch (e) {
      _showErrorMessage('ເກີດຂໍ້ຜິດພາດໃນການອັບເດດສະຖານະ: $e');
    }
  }

  Future<void> _updatePaymentStatus(
    String deliveryId,
    String currentStatus,
  ) async {
    try {
      final newStatus = currentStatus == 'paid' ? 'unpaid' : 'paid';
      await _deliveryCollection.doc(deliveryId).update({
        'paymentStatus': newStatus,
      });

      _showSuccessMessage('ອັບເດດສະຖານະການຈ່າຍເງິນສຳເລັດ');
    } catch (e) {
      _showErrorMessage('ເກີດຂໍ້ຜິດພາດໃນການອັບເດດສະຖານະການຈ່າຍເງິນ: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍການຈັດສົ່ງ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSelectionMode && _selectedDeliveries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 28),
              onPressed: _deleteSelectedDeliveries,
            ),
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.delete_outline,
              size: 28,
            ),
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ຄົ້ນຫາການຈັດສົ່ງ',
                labelStyle: const TextStyle(fontSize: 20),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchText = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusButton('all', 'ທັງໝົດ', Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatusButton('pending', 'ລໍຖ້າ', Colors.grey),
                  const SizedBox(width: 8),
                  _buildStatusButton(
                    'in_progress',
                    'ກຳລັງຈັດສົ່ງ',
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusButton('delivered', 'ຈັດສົ່ງແລ້ວ', Colors.green),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Delivery>>(
              stream: _getDeliveries(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນການຈັດສົ່ງ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                final allDeliveries = snapshot.data!;
                final filteredDeliveries = allDeliveries.where((d) {
                  final search = _searchText.toLowerCase();
                  return d.customerName.toLowerCase().contains(search) ||
                      d.customerPhone.toLowerCase().contains(search) ||
                      d.orderId.toLowerCase().contains(search);
                }).toList();
                final deliveries = _selectedStatus == 'all'
                    ? filteredDeliveries
                          .where((d) => d.deliveryStatus != 'cancelled')
                          .toList()
                    : filteredDeliveries
                          .where((d) => d.deliveryStatus == _selectedStatus)
                          .toList();

                if (deliveries.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນການຈັດສົ່ງ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (_isSelectionMode)
                      ListTile(
                        leading: Checkbox(
                          value: _selectAll,
                          onChanged: (_) => _toggleSelectAll(deliveries),
                        ),
                        title: Text(
                          'ເລືອກທັງໝົດ (${_selectedDeliveries.length}/${deliveries.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: ((() {
                          final total = deliveries.length;
                          final start = _currentPage * _rowsPerPage;
                          final end = (start + _rowsPerPage) > total
                              ? total
                              : (start + _rowsPerPage);
                          return end - start;
                        })()),
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final total = deliveries.length;
                          final start = _currentPage * _rowsPerPage;
                          final end = (start + _rowsPerPage) > total
                              ? total
                              : (start + _rowsPerPage);
                          final pageDeliveries = deliveries.sublist(start, end);
                          final delivery = pageDeliveries[index];
                          final isSelected = _selectedDeliveries.contains(
                            delivery.deliveryId,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ExpansionTile(
                              title: Row(
                                children: [
                                  if (_isSelectionMode)
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) =>
                                          _toggleDeliverySelection(
                                            delivery.deliveryId,
                                          ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      'ລະຫັດຄຳສັ່ງຊື້: ${delivery.orderId}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ລູກຄ້າ: ${delivery.customerName}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    'ວັນທີຈັດສົ່ງ: ${delivery.deliveryDate.toDate().toString().substring(0, 16)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        'ສະຖານະ: ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      _buildStatusChip(delivery.deliveryStatus),
                                    ],
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ທີ່ຢູ່: ${delivery.customerAddress}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      Text(
                                        'ເບີໂທ: ${delivery.customerPhone}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'ລາຍການສິນຄ້າ:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...delivery.items.map(
                                        (item) => Text(
                                          '- ${item['productName']} x${item['quantity']} ${item['unit']}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      if (delivery.items.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'ລາຄາລວມ: '
                                                '${delivery.items.fold<double>(0, (total, item) => total + ((item['price'] ?? 0) * (item['quantity'] ?? 0))).toStringAsFixed(0)} ກີບ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (delivery.deliveryNote.isNotEmpty) ...[
                                        const SizedBox(height: 0),
                                        Text(
                                          '\u0edd\u0eb2\u0e8d\u0ec0\u0eab\u0e94: ${delivery.deliveryNote}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      if (delivery.paymentStatus.isNotEmpty)
                                        Text(
                                          'ສະຖານະການຈ່າຍເງິນ: ${delivery.paymentStatus == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງບໍ່ທັນຈ່າຍ'}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color:
                                                delivery.paymentStatus == 'paid'
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (delivery.deliveryStatus ==
                                              'pending')
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _updateDeliveryStatus(
                                                        delivery.deliveryId,
                                                        'in_progress',
                                                      ),
                                                  icon: const Icon(
                                                    Icons.local_shipping,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  label: const Text(
                                                    'ເລີ່ມຈັດສົ່ງ',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.orange,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (delivery.deliveryStatus ==
                                              'in_progress')
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _updateDeliveryStatus(
                                                        delivery.deliveryId,
                                                        'delivered',
                                                      ),
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  label: const Text(
                                                    'ຢືນຢັນການຈັດສົ່ງ',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (delivery.paymentStatus.isNotEmpty)
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _updatePaymentStatus(
                                                        delivery.deliveryId,
                                                        delivery.paymentStatus,
                                                      ),
                                                  icon: Icon(
                                                    delivery.paymentStatus ==
                                                            'paid'
                                                        ? Icons.money_off
                                                        : Icons.payments,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  label: Text(
                                                    delivery.paymentStatus ==
                                                            'paid'
                                                        ? 'ຍັງບໍ່ທັນຈ່າຍ'
                                                        : 'ຈ່າຍແລ້ວ',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        delivery.paymentStatus ==
                                                            'paid'
                                                        ? Colors.red
                                                        : Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onExpansionChanged: (expanded) {
                                if (_isSelectionMode && expanded) {
                                  // Vela click lueak order hai pen karn lueak khor moon
                                  // Thaen t ja pen karn sadaeng details order
                                }
                              },
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
                              Text(
                                '   ${(_currentPage * _rowsPerPage) + 1} - ${((_currentPage * _rowsPerPage + _rowsPerPage) > deliveries.length ? deliveries.length : (_currentPage * _rowsPerPage + _rowsPerPage))} of ${deliveries.length}  ',
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed:
                                    ((_currentPage + 1) * _rowsPerPage) <
                                        deliveries.length
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DeliveryPage()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text(
            'ເພີ່ມການຈັດສົ່ງ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.grey;
        label = 'ລໍຖ້າ';
        break;
      case 'in_progress':
        color = Colors.orange;
        label = 'ກຳລັງຈັດສົ່ງ';
        break;
      case 'delivered':
        color = Colors.green;
        label = 'ຈັດສົ່ງແລ້ວ';
        break;
      default:
        color = Colors.grey;
        label = 'ລໍຖ້າ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusButton(String value, String label, Color color) {
    final bool selected = _selectedStatus == value;
    return ElevatedButton(
      onPressed: () => setState(() => _selectedStatus = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? color : Colors.transparent,
        foregroundColor: selected ? Colors.white : color,
        elevation: 0,
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}
