import 'package:flutter/material.dart';
import 'package:project/report/stocks_report.dart';
import 'package:project/report/production_report.dart';
import 'package:project/report/sales_report.dart';
import 'package:project/report/delivery_report.dart';
import 'package:project/report/customer_report.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ລາຍງານ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Text('📈', style: TextStyle(fontSize: 26)),
            title: const Text(
              'ລາຍງານຍອດຂາຍ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesReportPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Text('📦', style: TextStyle(fontSize: 28)),
            title: const Text(
              'ລາຍງານສິນຄ້າ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StocksReportPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Text('🏭', style: TextStyle(fontSize: 28)),
            title: const Text(
              'ລາຍງານ​ການ​ຜະ​ລິດ​',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductionReportPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Text('🚚', style: TextStyle(fontSize: 28)),
            title: Text(
              'ລາຍງານການຈັດສົ່ງ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DeliveryReportPage(),
                ),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Text('👥', style: TextStyle(fontSize: 28)),
            title: Text(
              'ລາຍງານລູກຄ້າ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerReportPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
