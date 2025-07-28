import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  const Customer({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  factory Customer.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      customerId: doc.id,
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
    );
  }
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final CollectionReference _customerCollection = FirebaseFirestore.instance
      .collection('Customers');
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSaving = false;

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  Future<String> _getNextCustomerId() async {
    final snapshot = await _customerCollection.get();
    final ids = snapshot.docs
        .map((doc) => doc.id)
        .where((id) => id.startsWith('C'))
        .map((id) => int.tryParse(id.substring(1)) ?? 0)
        .toList();
    int maxId = ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b);
    int nextId = maxId + 1;
    return 'C${nextId.toString().padLeft(3, '0')}';
  }

  Stream<List<Customer>> _getCustomers() {
    return _customerCollection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Customer.fromDocument(doc))
          .where(
            (customer) =>
                customer.customerName.toLowerCase().contains(
                  _search.toLowerCase(),
                ) ||
                customer.customerPhone.contains(_search) ||
                customer.customerAddress.toLowerCase().contains(
                  _search.toLowerCase(),
                ),
          )
          .toList(),
    );
  }

  void _showCustomerDialog({Customer? customer}) {
    final nameController = TextEditingController(
      text: customer?.customerName ?? '',
    );
    final phoneController = TextEditingController(
      text: customer?.customerPhone ?? '',
    );
    final addressController = TextEditingController(
      text: customer?.customerAddress ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, minWidth: 350),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                  child: Text(
                    customer == null
                        ? 'ເພີ່ມຂໍ້ມູນລູກຄ້າ'
                        : 'ແກ້ໄຂຂໍ້ມູນລູກຄ້າ',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'ຊື່',
                          labelStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: phoneController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'ເບີໂທ',
                          labelStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: addressController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'ທີ່ຢູ່',
                          labelStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'ຍົກເລີກ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final phone = phoneController.text.trim();
                                final address = addressController.text.trim();

                                String? errorMessage;
                                if (name.isEmpty) {
                                  errorMessage = 'ກະລຸນາໃສ່ຊື່ລູກຄ້າ';
                                } else if (phone.isEmpty) {
                                  errorMessage = 'ກະລຸນາໃສ່ເບີໂທລູກຄ້າ';
                                } else if (address.isEmpty) {
                                  errorMessage = 'ກະລຸນາໃສ່ທີ່ຢູ່ລູກຄ້າ';
                                }

                                if (errorMessage != null) {
                                  if (!context.mounted) return;
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => Container(
                                      margin: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                errorMessage!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text(
                                                'ຕົກລົງ',
                                                style: TextStyle(fontSize: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _isSaving = true);
                                if (!mounted) return;
                                final customerData = {
                                  'customerName': name,
                                  'customerPhone': phone,
                                  'customerAddress': address,
                                };

                                final phoneDuplicate = await _customerCollection
                                    .where('customerPhone', isEqualTo: phone)
                                    .get();
                                if (customer == null) {
                                  if (phoneDuplicate.docs.isNotEmpty) {
                                    setState(() => _isSaving = false);
                                    errorMessage = 'ເບີໂທນີ້ມີແລ້ວ';
                                  }
                                } else {
                                  if (phoneDuplicate.docs.any(
                                    (doc) => doc.id != customer.customerId,
                                  )) {
                                    setState(() => _isSaving = false);
                                    errorMessage = 'ເບີໂທນີ້ມີແລ້ວ';
                                  }
                                }
                                if (errorMessage != null) {
                                  if (!context.mounted) return;
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => Container(
                                      margin: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                errorMessage!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text(
                                                'ຕົກລົງ',
                                                style: TextStyle(fontSize: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  if (customer == null) {
                                    final newId = await _getNextCustomerId();
                                    final doc = await _customerCollection
                                        .doc(newId)
                                        .get();
                                    if (doc.exists) {
                                      setState(() => _isSaving = false);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('ລູກຄ້ານີ້ມີແລ້ວ'),
                                        ),
                                      );
                                      return;
                                    }
                                    await _customerCollection
                                        .doc(newId)
                                        .set(customerData);
                                  } else {
                                    await _customerCollection
                                        .doc(customer.customerId)
                                        .update(customerData);
                                  }
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  setState(() => _isSaving = false);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('ເກີດຂໍ້ຜິດພາດ: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  setState(() => _isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          customer == null ? 'ເພີ່ມ' : 'ບັນທຶກ',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteCustomer(String customerId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, minWidth: 350),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 24, 32, 0),
                  child: Text(
                    'ລຶບລູກຄ້າ',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 16, 32, 0),
                  child: Text(
                    'ແນ່ໃຈບໍ່ວ່າຕ້ອງການລຶບລູກຄ້ານີ້?',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'ຍົກເລີກ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _customerCollection.doc(customerId).delete();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ເກີດຂໍ້ຜິດພາດ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ລຶບ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ຈັດການຂໍ້ມູນລູກຄ້າ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, size: 30),
              onPressed: () => _showCustomerDialog(),
              tooltip: 'ເພີ່ມຂໍ້ມູນລູກຄ້າ',
            ),
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
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _getCustomers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('ເກີດຂໍ້ຜິດພາດ: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = snapshot.data ?? [];

                if (customers.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນລູກຄ້າ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                final total = customers.length;
                final start = _currentPage * _rowsPerPage;
                final end = (start + _rowsPerPage) > total
                    ? total
                    : (start + _rowsPerPage);
                final pageCustomers = customers.sublist(start, end);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: pageCustomers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final customer = pageCustomers[i];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(
                              customer.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'ເບີໂທ: ${customer.customerPhone}\nທີ່ຢູ່: ${customer.customerAddress}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showCustomerDialog(customer: customer),
                                  tooltip: 'ແກ້ໄຂ',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteCustomer(customer.customerId),
                                  tooltip: 'ລຶບ',
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
