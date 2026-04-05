import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// Adjust these imports to your project structure
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/payment_model.dart';

class PackagePaymentStatusCard extends ConsumerWidget {
  final String clientId;
  final VoidCallback? onTap;

  const PackagePaymentStatusCard({
    super.key,
    required this.clientId,
    this.onTap, // Added so it can trigger the detailed bottom sheet if needed
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageAsync = ref.watch(assignedPackageProvider(clientId));
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return packageAsync.when(
      loading: () => Container(
        height: 100,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: colorScheme.primary),
      ),
      error: (e, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Text("Data Error: $e", style: const TextStyle(color: Colors.red)),
      ),
      data: (assignments) {
        // Find the active plan
        final activeAssignment = assignments.firstWhereOrNull((a) => a.isActive);

        if (activeAssignment == null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 40, color: theme.hintColor.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text("No Active Plan", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Explore clinical programs to get started.", style: TextStyle(color: theme.hintColor, fontSize: 12)),
                ],
              ),
            ),
          );
        }
// Get the style for the tier badge
        final tierStyle = _getTierStyle(activeAssignment.category, colorScheme);
        // Fetch Payments
        return FutureBuilder<List<PaymentModel>>(
          future: PackageService().getPaymentsForAssignment(activeAssignment.id),
          builder: (context, snapshot) {
            final payments = snapshot.data ?? [];
            final double totalPaid = payments.fold(0.0, (sum, item) => sum + item.amount);
            final double netPayable = activeAssignment.bookedAmount;
            final double balance = netPayable - totalPaid;

            final double originalPrice = activeAssignment.originalPrice ?? netPayable;
            final bool hasDiscount = originalPrice > netPayable;

            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  collapsedIconColor: colorScheme.primary,
                  iconColor: colorScheme.primary,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: tierStyle['bg'], // Tier-specific background
                        shape: BoxShape.circle
                    ),
                    child: Icon(tierStyle['icon'], color: tierStyle['color'], size: 24), // Tier-specific icon
                  ),
                  title: Text(
                      activeAssignment.packageName,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.onSurface)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Wrap( // Use Wrap to prevent overflow on small screens
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // 🏆 THE TIER BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                              color: tierStyle['color'],
                              borderRadius: BorderRadius.circular(100), // Pill shape
                              boxShadow: [
                                BoxShadow(color: tierStyle['color'].withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                              ]
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tierStyle['icon'], size: 10, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                  tierStyle['label'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.8)
                              ),
                            ],
                          ),
                        ),

                        // 💰 PAYMENT STATUS BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: balance <= 0 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: balance <= 0 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2))
                          ),
                          child: Text(
                              balance <= 0 ? "FULLY PAID" : "DUE: ${currencyFormatter.format(balance)}",
                              style: TextStyle(
                                color: balance <= 0 ? Colors.green : Colors.orange.shade700,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                              )
                          ),
                        ),
                      ],
                    ),
                  ),


                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 20),

                          // 🚀 1. DATES (Timeline Style)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDateBlock("Started", activeAssignment.purchaseDate, theme),
                              Icon(Icons.arrow_right_alt_rounded, color: theme.dividerColor),
                              _buildDateBlock("Expires", activeAssignment.expiryDate, theme, isEnd: true),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 🚀 2. INCLUSIONS (What they get)
                          if (activeAssignment.inclusions.isNotEmpty) ...[
                            Text("Package Inclusions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: activeAssignment.inclusions.map((inc) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade400),
                                    const SizedBox(width: 6),
                                    Text(inc, style: TextStyle(fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // 🚀 3. FINANCIAL BREAKDOWN
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: isDark ? Colors.black.withOpacity(0.2) : Colors.blueGrey.shade50.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Billing Summary", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
                                const SizedBox(height: 12),

                                // Original Price & Discount Logic
                                if (hasDiscount) ...[
                                  _buildFinanceRow("Original Price", originalPrice, currencyFormatter, isStrikethrough: true, color: theme.hintColor),
                                  _buildFinanceRow("Offer Discount", originalPrice - netPayable, currencyFormatter, color: Colors.green),
                                ],

                                _buildFinanceRow("Booked Amount", netPayable, currencyFormatter, isBold: true, color: colorScheme.onSurface),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                _buildFinanceRow("Total Paid", totalPaid, currencyFormatter, color: Colors.blue),
                                _buildFinanceRow(
                                    "Pending Balance",
                                    balance > 0 ? balance : 0.0,
                                    currencyFormatter,
                                    color: balance > 0 ? Colors.red : Colors.green,
                                    isBold: true
                                ),
                              ],
                            ),
                          ),

                          // 🚀 4. PAYMENT HISTORY
                          // 🚀 4. PAYMENT HISTORY (Now with Payment Mode)
                          if (payments.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text("Payment History", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
                            const SizedBox(height: 12),

                            ...payments.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 🟢 Success Icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                  ),
                                  const SizedBox(width: 16),

                                  // 💳 Payment Mode & Date
                                  Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            // Replace 'paymentMode' with whatever your field is called in PaymentModel
                                              (p.paymentMethod ?? 'Online').toUpperCase(),
                                              style: TextStyle(
                                                  color: colorScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  letterSpacing: 0.5
                                              )
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                              DateFormat('MMM dd, yyyy • hh:mm a').format(p.paymentDate), // Added time for extra detail
                                              style: TextStyle(
                                                  color: theme.hintColor,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 11
                                              )
                                          )
                                        ],
                                      )
                                  ),

                                  // 💰 Amount
                                  Text(
                                      currencyFormatter.format(p.amount),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)
                                  ),
                                ],
                              ),
                            )),
                          ]
                        ],
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

  // --- HELPERS ---

  Widget _buildDateBlock(String label, DateTime date, ThemeData theme, {bool isEnd = false}) {
    return Column(
      crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildFinanceRow(String label, double amount, NumberFormat formatter, {bool isBold = false, Color? color, bool isStrikethrough = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Text(
              formatter.format(amount),
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                fontSize: isBold ? 16 : 14,
                color: color ?? Colors.black87,
                decoration: isStrikethrough ? TextDecoration.lineThrough : null,
                decorationColor: color,
              )
          ),
        ],
      ),
    );
  }
}

// Helper to get Tier styling based on the package type
Map<String, dynamic> _getTierStyle(String? type, ColorScheme colorScheme) {
  final String tier = (type ?? 'basic').toLowerCase();

  if (tier.contains('premium') || tier.contains('elite')) {
    return {
      'label': 'PREMIUM',
      'color': Colors.amber.shade700,
      'bg': Colors.amber.withOpacity(0.15),
      'icon': Icons.stars_rounded,
    };
  } else if (tier.contains('standard') || tier.contains('pro')) {
    return {
      'label': 'STANDARD',
      'color': Colors.blue.shade700,
      'bg': Colors.blue.withOpacity(0.1),
      'icon': Icons.verified_user_rounded,
    };
  } else {
    return {
      'label': 'BASIC',
      'color': Colors.teal.shade700,
      'bg': Colors.teal.withOpacity(0.1),
      'icon': Icons.spa_rounded,
    };
  }
}