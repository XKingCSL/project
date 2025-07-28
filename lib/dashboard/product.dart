import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Product {
  final String productId;
  final String productName;
  final String description;
  final String unit;
  final double price;
  final int stock;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  Product({
    required this.productId,
    required this.productName,
    required this.description,
    required this.unit,
    required this.price,
    required this.stock,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      productId: data['productId'] ?? doc.id,
      productName: data['productName'] ?? '',
      description: data['description'] ?? '',
      unit: data['unit'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stock: (data['stock'] ?? 0).toInt(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'description': description,
      'unit': unit,
      'price': price,
      'stock': stock,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() {
    return 'Product(productId: $productId, productName: $productName, price: $price, stock: $stock)';
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final CollectionReference _productCollection = FirebaseFirestore.instance
      .collection('Products');
  final CollectionReference _productChangesCollection = FirebaseFirestore
      .instance
      .collection('Production_Report');
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSaving = false;

  int _rowsPerPage = 10;
  int _currentPage = 0;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  Stream<List<Product>> _getProducts() {
    return _productCollection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .where(
            (product) =>
                product.productName.toLowerCase().contains(
                  _search.toLowerCase(),
                ) ||
                product.unit.toLowerCase().contains(_search.toLowerCase()) ||
                product.description.toLowerCase().contains(
                  _search.toLowerCase(),
                ),
          )
          .toList(),
    );
  }

  Future<String> generateProductId() async {
    final querySnapshot = await _productCollection
        .orderBy('productId', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 'Prod001';
    }

    final lastProductId =
        querySnapshot.docs.first.get('productId') as String? ?? 'Prod000';
    final lastNumber = int.parse(lastProductId.replaceAll('Prod', ''));
    final newNumber = lastNumber + 1;

    return 'Prod${newNumber.toString().padLeft(3, '0')}';
  }

  Future<void> _addProductHistory({
    required String productId,
    required String productName,
    required String action,
    String? changes,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    await _productChangesCollection.add({
      'productId': productId,
      'productName': productName,
      'action': action,
      'changes': changes,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUser?.displayName ?? 'unknown',
    });
  }

  void _showProductDialog({Product? product}) {
    final nameController = TextEditingController(
      text: product?.productName ?? '',
    );
    final descController = TextEditingController(
      text: product?.description ?? '',
    );
    final unitController = TextEditingController(text: product?.unit ?? '');
    final priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: product?.stock.toString() ?? '',
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                    child: Text(
                      product == null
                          ? 'ເພີ່ມຂໍ້ມູນສິນຄ້າ'
                          : 'ແກ້ໄຂຂໍ້ມູນສິນຄ້າ',
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
                            labelText: 'ຊື່ສິນຄ້າ',
                            labelStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: descController,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'ຄຳອະທິບາຍ',
                            labelStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: unitController,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'ຫົວໜ່ວຍ',
                            labelStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: priceController,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'ລາຄາ',
                            labelStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: stockController,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'ຈຳນວນ',
                            labelStyle: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          keyboardType: TextInputType.number,
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
                                  final desc = descController.text.trim();
                                  final unit = unitController.text.trim();
                                  final price =
                                      double.tryParse(
                                        priceController.text.trim(),
                                      ) ??
                                      0;
                                  final stock =
                                      int.tryParse(
                                        stockController.text.trim(),
                                      ) ??
                                      0;
                                  String? errorMessage;
                                  if (name.isEmpty) {
                                    errorMessage = 'ກະລຸນາໃສ່ຊື່ສິນຄ້າ';
                                  } else if (unit.isEmpty) {
                                    errorMessage = 'ກະລຸນາໃສ່ຫົວໜ່ວຍ';
                                  } else if (price <= 0) {
                                    errorMessage = 'ກະລຸນາໃສ່ລາຄາສິນຄ້າ';
                                  } else if (stock < 0) {
                                    errorMessage = 'ຈຳນວນສິນຄ້າຕ້ອງຫຼາຍກວ່າ 0';
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                  ),
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
                                  // Check for duplicate name (case-insensitive, not id)
                                  final duplicate = await _productCollection
                                      .where('productName', isEqualTo: name)
                                      .get();
                                  if (product == null) {
                                    if (duplicate.docs.isNotEmpty) {
                                      setState(() => _isSaving = false);
                                      if (!context.mounted) return;
                                      errorMessage = 'ຊື່ສິນຄ້ານີ້ມີແລ້ວ';
                                    }
                                  } else {
                                    if (duplicate.docs.any(
                                      (doc) => doc.id != product.productId,
                                    )) {
                                      setState(() => _isSaving = false);
                                      if (!context.mounted) return;
                                      errorMessage = 'ຊື່ສິນຄ້ານີ້ມີແລ້ວ';
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                  ),
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
                                    final now = Timestamp.now();
                                    if (product == null) {
                                      final newId = await generateProductId();
                                      await _productCollection.doc(newId).set({
                                        'productId': newId,
                                        'productName': name,
                                        'description': desc,
                                        'unit': unit,
                                        'price': price,
                                        'stock': stock,
                                        'createdAt': now,
                                        'updatedAt': now,
                                      });
                                      await _addProductHistory(
                                        productId: newId,
                                        productName: name,
                                        action: 'create',
                                        changes: 'ສ້າງສິນຄ້າໃໝ່',
                                      );
                                    } else {
                                      final changes = <String>[];
                                      if (product.productName != name) {
                                        changes.add(
                                          'ຊື່ສິນຄ້າຈາກ "${product.productName}" ເປັນ "$name"',
                                        );
                                      }
                                      if (product.description != desc) {
                                        changes.add(
                                          'ຄໍາອະທິບາຍຈາກ "${product.description}" ເປັນ "$desc"',
                                        );
                                      }
                                      if (product.unit != unit) {
                                        changes.add(
                                          'ໜ່ວຍຈາກ "${product.unit}" ເປັນ "$unit"',
                                        );
                                      }
                                      if (product.price != price) {
                                        changes.add(
                                          'ລາຄາຈາກ ${product.price} ເປັນ $price',
                                        );
                                      }
                                      if (product.stock != stock) {
                                        changes.add(
                                          'ຈໍານວນຈາກ ${product.stock} ເປັນ $stock',
                                        );
                                      }
                                      await _productCollection
                                          .doc(product.productId)
                                          .update({
                                            'productName': name,
                                            'description': desc,
                                            'unit': unit,
                                            'price': price,
                                            'stock': stock,
                                            'updatedAt': now,
                                          });
                                      if (changes.isNotEmpty) {
                                        await _addProductHistory(
                                          productId: product.productId,
                                          productName: name,
                                          action: 'edit',
                                          changes: changes.join(', '),
                                        );
                                      }
                                    }
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    setState(() => _isSaving = false);
                                  } catch (e) {
                                    setState(() => _isSaving = false);
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
                            product == null ? 'ເພີ່ມ' : 'ບັນທຶກ',
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
      ),
    );
  }

  void _deleteProduct(String productId) {
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
                    'ລຶບສິນຄ້າ',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 16, 32, 0),
                  child: Text(
                    'ແນ່ໃຈບໍ່ວ່າຕ້ອງການລຶບສິນຄ້ານີ້?',
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
                            final productDoc = await _productCollection
                                .doc(productId)
                                .get();
                            final productData =
                                productDoc.data() as Map<String, dynamic>;

                            await _productCollection.doc(productId).delete();

                            await _addProductHistory(
                              productId: productId,
                              productName: productData['productName'] as String,
                              action: 'delete',
                              changes: 'ລຶບສິນຄ້າ',
                            );

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
          'ຈັດການຂໍ້ມູນສິນຄ້າ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, size: 30),
              onPressed: () => _showProductDialog(),
              tooltip: 'ເພີ່ມຂໍ້ມູນສິນຄ້າ',
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
                labelText: 'ຄົ້ນຫາສິນຄ້າ',
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
            child: StreamBuilder<List<Product>>(
              stream: _getProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(': \\${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'ບໍ່ມີຂໍ້ມູນສິນຄ້າ',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                final total = products.length;
                final start = _currentPage * _rowsPerPage;
                final end = (start + _rowsPerPage) > total
                    ? total
                    : (start + _rowsPerPage);
                final pageProducts = products.sublist(start, end);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: pageProducts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = pageProducts[i];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2),
                            title: Text(
                              p.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'ລາຄາ: '
                              '${p.price % 1 == 0 ? p.price.toInt() : p.price} ກີບ\n'
                              'ຈຳນວນ: ${p.stock} ${p.unit}\n'
                              '${p.description.isNotEmpty ? 'ລາຍລະອຽດ: ${p.description}' : ''}',
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
                                      _showProductDialog(product: p),
                                  tooltip: 'ແກ້ໄຂ',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteProduct(p.productId),
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
