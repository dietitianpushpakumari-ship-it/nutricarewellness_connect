import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/payment_model.dart';
import 'package:collection/collection.dart';

// 🎯 UPDATED WIDGET: Takes clientId and fetches its own data
class PackagePaymentStatusCard extends ConsumerWidget {
  final String clientId;

  // Changed from 'required this.assignment' to 'required this.clientId'
  const PackagePaymentStatusCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageAsync = ref.watch(assignedPackageProvider(clientId));
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final colorScheme = Theme.of(context).colorScheme;

    return packageAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (e, __) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
      data: (assignments) {
        // Logic to find the "Active" plan
        final activeAssignment = assignments.firstWhereOrNull((a) => a.isActive);

        if (activeAssignment == null) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text("No active membership plan found.", style: TextStyle(color: Colors.grey))),
            ),
          );
        }

        // Nested Future to fetch payment history
        return FutureBuilder<List<PaymentModel>>(
          future: PackageService().getPaymentsForAssignment(activeAssignment.id),
          builder: (context, snapshot) {
            final payments = snapshot.data ?? [];

            final double totalPaid = payments.fold(0.0, (sum, item) => sum + item.amount);
            final double netPayable = activeAssignment.bookedAmount;
            final double balance = netPayable - totalPaid;

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.workspace_premium, color: Colors.amber.shade800),
                ),
                title: Text(activeAssignment.packageName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    balance <= 0 ? "Fully Paid ✅" : "Balance: ${currencyFormatter.format(balance)}",
                    style: TextStyle(
                        color: balance <= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600
                    )
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDateInfo("Started", activeAssignment.purchaseDate),
                            _buildDateInfo("Expires", activeAssignment.expiryDate),
                          ],
                        ),
                        const Divider(height: 30),
                        _buildFinanceRow("Agreed Amount", netPayable, currencyFormatter, isBold: true),
                        _buildFinanceRow("Total Paid", totalPaid, currencyFormatter, color: Colors.blue),
                        const Divider(),
                        _buildFinanceRow("Pending Balance", balance > 0 ? balance : 0.0, currencyFormatter, color: balance > 0 ? Colors.red : Colors.green, isBold: true),

                        const SizedBox(height: 20),
                        if (payments.isNotEmpty) ...[
                          const Align(alignment: Alignment.centerLeft, child: Text("History", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
                          const SizedBox(height: 8),
                          ...payments.map((p) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            title: Text(currencyFormatter.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('dd MMM yyyy').format(p.paymentDate)),
                          )).toList(),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateInfo(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildFinanceRow(String label, double amount, NumberFormat formatter, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          Text(formatter.format(amount), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: isBold ? 16 : 14, color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}