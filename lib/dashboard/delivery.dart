import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Delivery {
  final String deliveryId;
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final Timestamp deliveryDate;
  final String deliveryStatus;
  final List<Map<String, dynamic>> items;
  final String deliveryNote;
  final Timestamp? confirmedAt;
  final String paymentStatus;
  final Timestamp? createdAt;

  Delivery({
    required this.deliveryId,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.deliveryDate,
    required this.deliveryStatus,
    required this.items,
    required this.deliveryNote,
    this.confirmedAt,
    required this.paymentStatus,
    this.createdAt,
  });

  factory Delivery.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Delivery(
      deliveryId: doc.id,
      orderId: data['orderId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      deliveryDate: data['deliveryDate'] ?? Timestamp.now(),
      deliveryStatus: data['deliveryStatus'] ?? 'pending',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      deliveryNote: data['deliveryNote'] ?? '',
      confirmedAt: data['confirmedAt'],
      paymentStatus: data['paymentStatus'] ?? '',
      createdAt: data['createdAt'],
    );
  }
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final CollectionReference _deliveryCollection = FirebaseFirestore.instance
      .collection('Deliveries');
  final CollectionReference _orderCollection = FirebaseFirestore.instance
      .collection('Orders');

  String? _selectedOrderId;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedCustomerAddress;
  String? _selectedCustomerPhone;
  List<Map<String, dynamic>> _selectedItems = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _note = '';
  final TextEditingController _noteController = TextEditingController();
  String? _selectedPaymentStatus;

  Future<void> _selectOrder() async {
    final ordersSnapshot = await _orderCollection
        .orderBy('orderDate', descending: true)
        .get();

    if (!mounted) return;

    if (ordersSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ບໍ່ມີຄຳສັ່ງຊື້')));
      return;
    }

    final deliveriesSnapshot = await _deliveryCollection.get();
    final existingOrderIds = deliveriesSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['orderId'] as String)
        .toSet();

    final availableOrders = ordersSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final orderIdFromOrder = data['orderId']?.toString() ?? '';
      final isExisting = existingOrderIds.contains(orderIdFromOrder);
      return !isExisting;
    }).toList();

    if (!mounted) return;

    if (availableOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ທຸກຄຳສັ່ງຊື້ໄດ້ຖືກຈັດສົ່ງແລ້ວ')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        String searchText = '';
        List<QueryDocumentSnapshot> filteredOrders = availableOrders;
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            filteredOrders = availableOrders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final search = searchText.toLowerCase();
              return data['customerName'].toString().toLowerCase().contains(
                    search,
                  ) ||
                  (data['customerPhone'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(search) ||
                  doc.id.toString().toLowerCase().contains(search);
            }).toList();
            return Dialog(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ເລືອກຄຳສັ່ງຊື້',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'ຄົ້ນຫາຄຳສັ່ງຊື້',
                        labelStyle: const TextStyle(fontSize: 20),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    searchText = '';
                                    searchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (filteredOrders.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'ບໍ່ມີຂໍ້ມູນຄຳສັ່ງຊື້',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final data = order.data() as Map<String, dynamic>;
                            final items = List<Map<String, dynamic>>.from(
                              data['items'] ?? [],
                            );
                            final totalItems = items.fold<int>(
                              0,
                              (total, item) =>
                                  total + (item['quantity'] as int),
                            );

                            return Card(
                              child: ListTile(
                                title: Text(
                                  'ລະຫັດ: ${data['orderId'] ?? ''}\nລູກຄ້າ: ${data['customerName']}\nເບີໂທ: ${data['customerPhone'] ?? ''}\nທີ່ຢູ່: ${data['customerAddress']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ວັນທີສັ່ງ: ${(data['orderDate'] as Timestamp).toDate().toString().substring(0, 16)}',
                                    ),
                                    Text('ຈຳນວນລາຍການ: $totalItems ລາຍການ'),
                                    Text(
                                      'ລາຄາລວມ: ${data['totalPrice']?.toStringAsFixed(0) ?? '0'} ກີບ',
                                    ),
                                    Text(
                                      'ສະຖານະການຈ່າຍເງິນ: ${data['paymentStatus'] == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງໄດ້ຈ່າຍ'}',
                                      style: TextStyle(
                                        color: data['paymentStatus'] == 'paid'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _selectedOrderId = data['orderId'];
                                  _selectedCustomerId = data['customerId'];
                                  _selectedCustomerName = data['customerName'];
                                  _selectedCustomerAddress =
                                      data['customerAddress'] ?? '';
                                  _selectedCustomerPhone =
                                      data['customerPhone'] ?? '';
                                  _selectedItems = items;
                                  _selectedPaymentStatus =
                                      data['paymentStatus'];
                                  Navigator.pop(context);
                                  this.setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );

      if (time != null) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      }
    }
  }

  Future<void> _saveDelivery() async {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ກະລຸນາເລືອກຄຳສັ່ງຊື້')));
      return;
    }

    try {
      final deliveryDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      String? adminName = '';
      try {
        adminName = FirebaseAuth.instance.currentUser?.displayName ?? '';
      } catch (_) {
        adminName = '';
      }
      await _deliveryCollection.add({
        'orderId': _selectedOrderId,
        'customerId': _selectedCustomerId,
        'customerName': _selectedCustomerName,
        'customerAddress': _selectedCustomerAddress,
        'customerPhone': _selectedCustomerPhone,
        'deliveryDate': Timestamp.fromDate(deliveryDate),
        'deliveryStatus': 'pending',
        'items': _selectedItems,
        'deliveryNote': _note,
        'createdAt': Timestamp.now(),
        'paymentStatus': _selectedPaymentStatus ?? '',
        'confirmedAt': Timestamp.now(),
        'adminName': adminName,
      });

      setState(() {
        _selectedOrderId = null;
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _selectedCustomerAddress = null;
        _selectedCustomerPhone = null;
        _selectedItems = [];
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
        _note = '';
        _noteController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ບັນທຶກຂໍ້ມູນການຈັດສົ່ງສຳເລັດ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e')));
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ຈັດການການຈັດສົ່ງ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ຂໍ້ມູນຄຳສັ່ງຊື້',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectOrder,
                          icon: const Icon(Icons.search),
                          label: const Text(
                            'ເລືອກຄຳສັ່ງຊື້',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedOrderId != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'ລະຫັດຄຳສັ່ງຊື້: $_selectedOrderId',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ລູກຄ້າ: $_selectedCustomerName',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ເບີໂທ: ${_selectedCustomerPhone ?? ''}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ທີ່ຢູ່: $_selectedCustomerAddress',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ລາຍການສິນຄ້າ:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._selectedItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '- ${item['productName']} x${item['quantity']} ${item['unit']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      if (_selectedItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ລາຄາລວມ: ${_selectedItems.fold<double>(0, (total, item) => total + ((item['price'] ?? 0) * (item['quantity'] ?? 0))).toStringAsFixed(0)} ກີບ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                              if (_selectedPaymentStatus != null)
                                Text(
                                  'ສະຖານະການຈ່າຍເງິນ: '
                                  '${_selectedPaymentStatus == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງ​ບໍ່​ໄດ້​ຈ່າຍ​'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedPaymentStatus == 'paid'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ຂໍ້ມູນການຈັດສົ່ງ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ວັນທີ ແລະ ເວລາຈັດສົ່ງ: ${_selectedDate.toString().substring(0, 10)} ${_selectedTime.format(context)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectDateTime,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text(
                            'ເລືອກເວລາ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'ໝາຍເຫດ',
                        labelStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) => _note = value,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveDelivery,
                icon: const Icon(Icons.save),
                label: const Text(
                  'ບັນທຶກຂໍ້ມູນການຈັດສົ່ງ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
