import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'order_history.dart';

class Order {
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final List<Map<String, dynamic>> items;
  final double totalPrice;
  final String paymentStatus;
  final Timestamp orderDate;
  final String orderNote;

  Order({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.items,
    required this.totalPrice,
    required this.paymentStatus,
    required this.orderDate,
    required this.orderNote,
  });

  factory Order.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      orderId: data['orderId'] ?? doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      orderDate: data['orderDate'] ?? Timestamp.now(),
      orderNote: data['orderNote'] ?? '',
    );
  }

  Future<void> generateInvoice() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Phetsarath_OT.ttf');
    final laoFont = pw.Font.ttf(fontData);
    final now = DateTime.now();
    final orderData = {
      'orderId': orderId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'items': items.map((item) {
        return {
          'productName': item['productName'],
          'quantity': item['quantity'],
          'unitPrice': item['price'],
          'total': item['price'] * item['quantity'],
        };
      }).toList(),
      'totalPrice': totalPrice,
      'createdAt': orderDate,
    };

    pdf.addPage(
      pw.Page(
        build: (context) => pw.DefaultTextStyle(
          style: pw.TextStyle(font: laoFont, fontSize: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ໃບບິນຂອງໂລມາຄຳ', style: pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text('ລະຫັດຄໍາສັ່ງຊື້: ${orderData['orderId']}'),
              pw.Text('ວັນທີ: ${now.day}/${now.month}/${now.year}'),
              pw.Text('ລູກຄ້າ: ${orderData['customerName']}'),
              pw.Text('ທີ່ຢູ່: ${orderData['customerAddress']}'),
              pw.Text(
                'ສະຖານະການຈ່າຍເງິນ: ${paymentStatus == 'paid' ? 'ຈ່າຍແລ້ວ' : 'ຍັງບໍ່ໄດ້ຈ່າຍ'}',
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['ສິນຄ້າ', 'ຈໍານວນ', 'ລາຄາ', 'ລວມ'],
                data: (orderData['items'] as List).map((item) {
                  return [
                    item['productName'],
                    item['quantity'].toString(),
                    item['unitPrice'].toStringAsFixed(2),
                    item['total'].toStringAsFixed(2),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'ລວມທັງໝົດ: ${(orderData['totalPrice'] as num).toStringAsFixed(2)} ກີບ',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final CollectionReference _orderCollection = FirebaseFirestore.instance
      .collection('Orders');
  final CollectionReference _customerCollection = FirebaseFirestore.instance
      .collection('Customers');
  final CollectionReference _productCollection = FirebaseFirestore.instance
      .collection('Products');

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedCustomerAddress;
  String? _selectedCustomerPhone;
  List<Map<String, dynamic>> _orderItems = [];
  double _totalPrice = 0;
  String _paymentStatus = 'unpaid';
  String _note = '';
  String _customerSearch = '';
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _fetchProducts();
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers({bool showAll = false}) async {
    final snapshot = await _customerCollection.get();
    setState(() {
      _customers = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'customerId': doc.id,
              'customerName': data['customerName'] ?? '',
              'customerAddress': data['customerAddress'] ?? '',
              'customerPhone': data['customerPhone'] ?? '',
            };
          })
          .where(
            (customer) =>
                showAll ||
                customer['customerName'].toString().toLowerCase().contains(
                  _customerSearch.toLowerCase(),
                ),
          )
          .toList();
    });
  }

  Future<void> _fetchProducts() async {
    final snapshot = await _productCollection.get();
    setState(() {
      _products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'productId': data['productId'] ?? doc.id,
          'productName': data['productName'] ?? '',
          'unit': data['unit'] ?? '',
          'price': (data['price'] ?? 0).toDouble(),
        };
      }).toList();
    });
  }

  void _addOrderItem() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedProductId;
        int quantity = 1;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400, minWidth: 350),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ເພີ່ມສິນຄ້າ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedProductId,
                        isExpanded: true,
                        items: _products.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['productId'],
                            child: Text(
                              '${p['productName']} (${p['unit']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => selectedProductId = val),
                        decoration: const InputDecoration(
                          labelText: 'ເລືອກສິນຄ້າ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ຈຳນວນ',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) =>
                              setState(() => quantity = int.tryParse(val) ?? 1),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'ຍົກເລີກ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (selectedProductId != null) {
                                final product = _products.firstWhere(
                                  (p) => p['productId'] == selectedProductId,
                                );
                                _orderItems.add({
                                  'productId': product['productId'],
                                  'productName': product['productName'],
                                  'price': product['price'],
                                  'quantity': quantity,
                                  'unit': product['unit'],
                                });
                                Navigator.pop(context);
                                setState(() {});
                                _calculateTotal();
                              }
                            },
                            child: const Text(
                              'ເພີ່ມ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _calculateTotal() {
    _totalPrice = 0;
    for (var item in _orderItems) {
      _totalPrice += (item['price'] as double) * (item['quantity'] as int);
    }
    setState(() {});
  }

  void _saveOrder() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ກະລຸນາເລືອກລູກຄ້າ')));
      setState(() => _isSaving = false);
      return;
    }
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ກະລຸນາເພີ່ມລາຍການສິນຄ້າ')));
      setState(() => _isSaving = false);
      return;
    }

    // Check stock before saving order
    bool outOfStock = false;
    String outOfStockProduct = '';
    for (final item in _orderItems) {
      final productSnap = await _productCollection.doc(item['productId']).get();
      final productData = productSnap.data() as Map<String, dynamic>;
      final stock = (productData['stock'] ?? 0) as int;
      if (stock < (item['quantity'] as int)) {
        outOfStock = true;
        outOfStockProduct = item['productName'] ?? '';
        break;
      }
    }
    if (outOfStock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ບໍ່ສາມາດບັນທຶກໄດ້ຍ້ອນວ່າ $outOfStockProduct ບໍ່ພໍ ຫຼື ໝົດແລ້ວ',
          ),
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    final now = Timestamp.now();
    final orderId = await generateOrderId();
    final orderData = {
      'orderId': orderId,
      'customerId': _selectedCustomerId,
      'customerName': _selectedCustomerName,
      'customerAddress': _selectedCustomerAddress,
      'customerPhone': _selectedCustomerPhone,
      'items': _orderItems,
      'totalPrice': _totalPrice,
      'paymentStatus': _paymentStatus,
      'orderDate': now,
      'orderNote': _note,
    };

    try {
      await _orderCollection.doc(orderId).set(orderData);

      for (final item in _orderItems) {
        final productRef = _productCollection.doc(item['productId']);
        await productRef.update({
          'stock': FieldValue.increment(-(item['quantity'] as int)),
        });
      }

      if (!mounted) return;
      setState(() {
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _selectedCustomerAddress = null;
        _selectedCustomerPhone = null;
        _orderItems = [];
        _totalPrice = 0;
        _paymentStatus = 'unpaid';
        _note = '';
        _customerSearch = '';
        _customerSearchController.clear();
        _noteController.clear();
        _customers.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ບັນທຶກການຂາຍສຳເລັດ')));
      setState(() => _isSaving = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e')));
      setState(() => _isSaving = false);
    }
  }

  Future<String> generateOrderId() async {
    final counterRef = FirebaseFirestore.instance
        .collection('OrderCounter')
        .doc('OrderCounter');
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int last = snapshot.exists ? (snapshot.get('last') as int? ?? 0) : 0;
      final next = last + 1;
      transaction.set(counterRef, {'last': next});
      return 'Order${next.toString().padLeft(3, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ຂາຍສິນຄ້າ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 28),
            tooltip: 'ປະຫວັດການຂາຍ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _customerSearchController,
                decoration: InputDecoration(
                  labelText: 'ຄົ້ນຫາລູກຄ້າ',
                  labelStyle: const TextStyle(fontSize: 20),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _customerSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _customerSearch = '';
                              _customerSearchController.clear();
                              _selectedCustomerId = null;
                              _selectedCustomerName = null;
                              _selectedCustomerAddress = null;
                              _selectedCustomerPhone = null;
                            });
                            _fetchCustomers(showAll: true);
                          },
                        )
                      : null,
                ),
                onTap: () {
                  setState(() {
                    _customerSearch = '';
                    _customerSearchController.clear();
                  });
                  _fetchCustomers(showAll: true);
                },
                onChanged: (value) {
                  setState(() {
                    _customerSearch = value;
                  });
                  _fetchCustomers();
                },
              ),
              if (_customers.isNotEmpty &&
                  (_customerSearch.isNotEmpty ||
                      _customerSearchController.text.isEmpty))
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      return ListTile(
                        title: Text(customer['customerName']),
                        subtitle: Text(
                          'ທີ່ຢູ່: ${customer['customerAddress']}',
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = customer['customerId'];
                            _selectedCustomerName = customer['customerName'];
                            _selectedCustomerAddress =
                                customer['customerAddress'];
                            _selectedCustomerPhone = customer['customerPhone'];
                            _customerSearch = customer['customerName'];
                            _customerSearchController.text =
                                customer['customerName'];
                            _customers.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ລາຍການສິນຄ້າ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addOrderItem,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'ເພີ່ມສິນຄ້າ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._orderItems.map((item) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('${item['productName']}'),
                    subtitle: Text(
                      'ລະຫັດສິນຄ້າ: ${item['productId']}\n'
                      'ຈຳນວນ: ${item['quantity']} ${item['unit']}\n'
                      'ລາຄາຕໍ່ຫົວໜ່ວຍ: ${item['price'] % 1 == 0 ? item['price'].toInt() : item['price']} ກີບ',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _orderItems.remove(item);
                          _calculateTotal();
                        });
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              Text(
                'ລາຄາລວມ: ${_totalPrice % 1 == 0 ? _totalPrice.toInt() : _totalPrice} ກີບ',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                items: const [
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text('ຍັງບໍ່ໄດ້ຈ່າຍ'),
                  ),
                  DropdownMenuItem(value: 'paid', child: Text('ຈ່າຍແລ້ວ')),
                ],
                onChanged: (val) =>
                    setState(() => _paymentStatus = val ?? 'unpaid'),
                decoration: const InputDecoration(
                  labelText: 'ສະຖານະການຈ່າຍເງິນ',
                  labelStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
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
                onChanged: (val) => _note = val,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'ບັນທຶກການຂາຍ',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  if (_selectedCustomerId == null) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('ກະລຸນາເລືອກລູກຄ້າ')),
                    );
                    return;
                  }
                  if (_orderItems.isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('ກະລຸນາເພີ່ມລາຍການສິນຄ້າ')),
                    );
                    return;
                  }
                  final counterRef = FirebaseFirestore.instance
                      .collection('OrderCounter')
                      .doc('OrderCounter');
                  final snapshot = await counterRef.get();
                  final last = snapshot.exists
                      ? (snapshot.get('last') as int? ?? 0)
                      : 0;
                  final currentOrderId =
                      'Order${(last + 1).toString().padLeft(3, '0')}';
                  final order = Order(
                    orderId: currentOrderId,
                    customerId: _selectedCustomerId!,
                    customerName: _selectedCustomerName!,
                    customerAddress: _selectedCustomerAddress!,
                    customerPhone: _selectedCustomerPhone!,
                    items: _orderItems,
                    totalPrice: _totalPrice,
                    paymentStatus: _paymentStatus,
                    orderDate: Timestamp.now(),
                    orderNote: _note,
                  );

                  try {
                    await order.generateInvoice();
                  } catch (e) {
                    if (!context.mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.receipt_long, color: Colors.white),
                label: const Text(
                  'ສ້າງໃບບິນ',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
