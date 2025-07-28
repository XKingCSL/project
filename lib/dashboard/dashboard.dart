import 'package:project/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/dashboard/order.dart';
import 'package:project/dashboard/product.dart';
import 'package:project/report/report.dart';
import 'customer.dart';
import 'package:project/dashboard/delivery_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  const DashboardPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Widget _buildOverviewCard(
    BuildContext context, {
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required Widget value,
    required Color color,
  }) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget ?? Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            value,
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getTodaySoldAmount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('Deliveries')
        .where('confirmedAt', isGreaterThanOrEqualTo: start)
        .where('confirmedAt', isLessThanOrEqualTo: end)
        .where('deliveryStatus', isEqualTo: 'delivered')
        .where('paymentStatus', isEqualTo: 'paid')
        .get();
    double total = 0;
    for (final doc in deliveriesSnapshot.docs) {
      final data = doc.data();
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      final price = items.fold<double>(
        0,
        (acc, item) => acc + ((item['price'] ?? 0) * (item['quantity'] ?? 0)),
      );
      total += price;
    }
    return '${total.toStringAsFixed(0)} ກີບ';
  }

  Future<int> _getPendingDeliveryCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Deliveries')
        .where('deliveryStatus', isEqualTo: 'pending')
        .get();
    return snapshot.docs.length;
  }

  Future<int> _getLowStockCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Products')
        .where('stock', isLessThanOrEqualTo: 20)
        .get();
    return snapshot.docs.length;
  }

  Future<int> _getUnpaidOrderCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Orders')
        .where('paymentStatus', isNotEqualTo: 'paid')
        .get();
    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {});
          },
          child: Text(
            'ໜ້າຫຼັກ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Color.fromARGB(255, 65, 65, 65),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => _buildSettingsSheet(context),
              );
            },
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.toggleTheme,
            tooltip: widget.isDarkMode ? 'ສະຫຼັບໂໝດ' : 'ສະຫຼັບໂໝດ',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        FutureBuilder<String>(
                          future: _getTodaySoldAmount(),
                          builder: (context, snapshot) {
                            return _buildOverviewCard(
                              context,
                              iconWidget: const Text(
                                '₭',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              title: 'ຍອດຂາຍມື້ນີ້',
                              value: Text(
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? '...'
                                    : (snapshot.data ?? '0 ກີບ'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                ),
                              ),
                              color: Colors.green,
                            );
                          },
                        ),
                        FutureBuilder<int>(
                          future: _getPendingDeliveryCount(),
                          builder: (context, snapshot) {
                            return _buildOverviewCard(
                              context,
                              icon: Icons.local_shipping,
                              title: 'ທີ່ບໍ່ໄດ້ຈັດສົ່ງ',
                              value: Text(
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? '...'
                                    : '${snapshot.data ?? 0} ລາຍການ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                ),
                              ),
                              color: Colors.orange,
                            );
                          },
                        ),
                        FutureBuilder<int>(
                          future: _getLowStockCount(),
                          builder: (context, snapshot) {
                            return _buildOverviewCard(
                              context,
                              icon: Icons.inventory_2,
                              title: 'ສິນຄ້າທີ່ຈະໝົດ',
                              value: Text(
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? '...'
                                    : '${snapshot.data ?? 0} ລາຍການ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              color: Colors.deepPurple,
                            );
                          },
                        ),
                        FutureBuilder<int>(
                          future: _getUnpaidOrderCount(),
                          builder: (context, snapshot) {
                            return _buildOverviewCard(
                              context,
                              icon: Icons.receipt_long,
                              title: 'ທີ່ບໍ່ໄດ້ຈ່າຍ',
                              value: Text(
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? '...'
                                    : '${snapshot.data ?? 0} ລາຍການ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              color: Colors.red,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text(
                  'ຂໍ້ມູນລູກຄ້າ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.teal),
                title: const Text(
                  'ຂໍ້ມູນສິນຄ້າ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.receipt_long,
                  color: Colors.deepPurple,
                ),
                title: const Text(
                  'ຂາຍສິນຄ້າ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OrderPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.orange),
                title: const Text(
                  'ການຈັດສົ່ງ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DeliveryListPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.green),
                title: const Text(
                  'ລາຍງານ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReportPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'No display name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    Text(
                      user?.email ?? 'No email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => LoginPage(
                        toggleTheme: widget.toggleTheme,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
