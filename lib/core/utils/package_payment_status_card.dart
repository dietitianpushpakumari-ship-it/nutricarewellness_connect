import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:pure_shift/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:pure_shift/features/profile/client_reminder_setting_screen.dart';



// Adjust these imports to your project structure
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/dATA/services/package_service.dart';
import 'package:pure_shift/features/dietplan/domain/entities/payment_model.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';
import 'package:pure_shift/new/utils/utils.dart';

import '../../layout_utils.dart';

// 🎯 GLOBAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class PackagePaymentStatusCard extends ConsumerWidget {
  final String clientId;

  const PackagePaymentStatusCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currentClient = ref.watch(currentClientProvider);
    final String tenantId = currentClient?.tenantId ?? 'guest';

    return StreamBuilder<List<PackageAssignmentModel>>(
      stream: PackageService().streamPackageAssignments(clientId, tenantId),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Error State
        if (snapshot.hasError) {
          debugPrint('🔥 FIREBASE STREAM ERROR: ${snapshot.error}');
          return Container(
            padding: EdgeInsets.all(context.scale(16)),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(context.scale(16)),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Text(
              "System Error. Check console logs.",
              style: TextStyle(fontFamily: kBodyFont, color: colorScheme.error, fontSize: context.scale(11), fontWeight: FontWeight.w600),
            ),
          );
        }

        // 3. Extract Data
        final assignments = snapshot.data ?? [];
        final activeAssignment = assignments.firstWhereOrNull((a) => a.isActive);

        if (activeAssignment == null) return _buildNoPlanCard(context, theme);

        final tierStyle = _getTierStyle(activeAssignment.category ?? activeAssignment.type, colorScheme);

        // 4. Success UI (Compact Bento Card)
        return GestureDetector(
          onTap: () => _showPackageDetailSheet(context, activeAssignment, ref),
          child: Container(
            padding: EdgeInsets.all(context.scale(16)), // Tighter padding
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(context.scale(20)),
              border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: context.scale(10), offset: Offset(0, context.scale(4)))
              ],
            ),
            child: Row(
              children: [
                // 🏷️ Tier Icon
                Container(
                  padding: EdgeInsets.all(context.scale(12)),
                  decoration: BoxDecoration(color: tierStyle['bg'], shape: BoxShape.circle),
                  child: Icon(tierStyle['icon'], color: tierStyle['color'], size: context.scale(24)),
                ),
                SizedBox(width: context.scale(16)),

                // 📝 Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🏆 THE TIER BADGE
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: context.scale(6), vertical: context.scale(2)),
                        decoration: BoxDecoration(
                            color: tierStyle['color'].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(context.scale(6)),
                            border: Border.all(color: tierStyle['color'].withOpacity(0.3))
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tierStyle['icon'], size: context.scale(8), color: tierStyle['color']),
                            SizedBox(width: context.scale(4)),
                            Text(
                                tierStyle['label'],
                                style: TextStyle(fontFamily: kDisplayFont, color: tierStyle['color'], fontWeight: FontWeight.w900, fontSize: context.scale(8), letterSpacing: context.scale(0.8))
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.scale(6)),
                      Text(
                        activeAssignment.packageName.capitalize(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(12), color: colorScheme.onSurface, letterSpacing: context.scale(-0.5)),
                      ),
                      SizedBox(height: context.scale(2)),
                      Text(
                        "Valid until ${DateFormat('MMM dd, yyyy').format(activeAssignment.expiryDate)}",
                        style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(11), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                // ℹ️ ACTION BUTTON
                SizedBox(width: context.scale(12)),
                Container(
                  padding: EdgeInsets.all(context.scale(8)),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: context.scale(14), color: isDark ? Colors.white54 : theme.hintColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoPlanCard(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: context.scale(24), horizontal: context.scale(16)),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(context.scale(20)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08))
      ),
      child: Column(
        children: [
          Icon(Icons.health_and_safety_outlined, size: context.scale(32), color: theme.disabledColor),
          SizedBox(height: context.scale(12)),
          Text("No active clinical program", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(12), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // 🚀 1. THE BULLETPROOF OLED-PREMIUM BOTTOM SHEET
  void _showPackageDetailSheet(BuildContext context, PackageAssignmentModel plan, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final currentClient = ref.read(currentClientProvider);
    final String tenantId = currentClient?.tenantId ?? 'guest';

    final tierStyle = _getTierStyle(plan.category ?? plan.type, colorScheme);

    // 🌑 Deep OLED Colors
    final Color sheetBackground = isDark ? const Color(0xFF0F131D) : theme.scaffoldBackgroundColor;
    final Color cardBackground = isDark ? Colors.white.withOpacity(0.03) : Colors.white;
    final Color borderColor = theme.dividerColor.withOpacity(isDark ? 0.08 : 0.05);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.88,
        decoration: BoxDecoration(
          color: sheetBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.scale(32))),
          border: Border(top: BorderSide(color: tierStyle['color'].withOpacity(isDark ? 0.3 : 0.1), width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: ctx.scale(40), offset: Offset(0, ctx.scale(-10)))],
        ),
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              // 🏁 Header Row: Drag Handle + Close Button
              Padding(
                padding: EdgeInsets.fromLTRB(ctx.scale(20), ctx.scale(12), ctx.scale(12), ctx.scale(8)),
                child: Row(
                  children: [
                    const Spacer(flex: 2), // Keeps handle centered
                    // Center Drag Handle
                    Container(
                      width: ctx.scale(40), height: ctx.scale(4),
                      decoration: BoxDecoration(
                          color: theme.dividerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ctx.scale(2))
                      ),
                    ),
                    const Spacer(),
                    // 🚀 THE FIX: Modern Close Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(ctx.scale(20)),
                        child: Container(
                          padding: EdgeInsets.all(ctx.scale(8)),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.close_rounded,
                              size: ctx.scale(16),
                              color: isDark ? Colors.white70 : theme.hintColor
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: ctx.scale(20)),
                  children: [
                    // 🏆 1. THE ELITE MEMBERSHIP HEADER
                    Container(
                      padding: EdgeInsets.all(ctx.scale(20)),
                      decoration: BoxDecoration(
                        color: cardBackground,
                        borderRadius: BorderRadius.circular(ctx.scale(24)),
                        border: Border.all(color: borderColor),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.02), blurRadius: ctx.scale(10), offset: Offset(0, ctx.scale(4)))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: ctx.scale(10), vertical: ctx.scale(4)),
                                decoration: BoxDecoration(color: tierStyle['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(ctx.scale(8)), border: Border.all(color: tierStyle['color'].withOpacity(0.3))),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(tierStyle['icon'], size: ctx.scale(10), color: tierStyle['color']),
                                    SizedBox(width: ctx.scale(6)),
                                    Text(tierStyle['label'], style: TextStyle(fontFamily: kDisplayFont, color: tierStyle['color'], fontWeight: FontWeight.w900, fontSize: ctx.scale(9), letterSpacing: ctx.scale(1.0))),
                                  ],
                                ),
                              ),
                              Icon(Icons.health_and_safety_rounded, color: theme.dividerColor.withOpacity(0.1), size: ctx.scale(24)),
                            ],
                          ),
                          SizedBox(height: ctx.scale(16)),
                          Text(plan.packageName.capitalize(), style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(12), fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: ctx.scale(-0.5))),
                          SizedBox(height: ctx.scale(20)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDateColumn(ctx, "VALID FROM", plan.purchaseDate, theme, isDark),
                              Icon(Icons.arrow_right_alt_rounded, color: theme.dividerColor.withOpacity(0.3)),
                              _buildDateColumn(ctx, "EXPIRES ON", plan.expiryDate, theme, isDark, isEnd: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: ctx.scale(24)),

                    // ✅ 2. PACKAGE INCLUSIONS
                    _sectionHeader(ctx, "PROGRAM BENEFITS", Icons.auto_awesome_rounded, colorScheme, isDark),
                    Container(
                      padding: EdgeInsets.all(ctx.scale(16)),
                      decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(ctx.scale(20)), border: Border.all(color: borderColor)),
                      child: Column(
                        children: plan.inclusions.map((inc) => Padding(
                          padding: EdgeInsets.symmetric(vertical: ctx.scale(8)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: ctx.scale(2)),
                                padding: EdgeInsets.all(ctx.scale(4)),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(isDark ? 0.2 : 0.1), shape: BoxShape.circle),
                                child: Icon(Icons.check_rounded, size: ctx.scale(10), color: isDark ? Colors.greenAccent : Colors.green),
                              ),
                              SizedBox(width: ctx.scale(12)),
                              Expanded(child: Text(inc, style: TextStyle(fontFamily: kBodyFont, fontSize: ctx.scale(9), fontWeight: FontWeight.w500, color: colorScheme.onSurface, height: 1.3))),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),

                    SizedBox(height: ctx.scale(24)),

                    // 💰 3. CLINICAL INVOICE & BILLING
                    _sectionHeader(ctx, "FINANCIAL SUMMARY", Icons.account_balance_wallet_rounded, colorScheme, isDark),

                    StreamBuilder<List<PaymentModel>>(
                      stream: PackageService().streamPaymentsForAssignment(plan.id, tenantId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Padding(padding: EdgeInsets.all(ctx.scale(24)), child: const Center(child: CircularProgressIndicator()));
                        }

                        final payments = snapshot.data ?? [];
                        final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
                        final netPayable = plan.bookedAmount;
                        final balance = netPayable - totalPaid;

                        final double originalPrice = plan.originalPrice ?? netPayable;
                        final bool hasDiscount = originalPrice > netPayable;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(ctx.scale(16)),
                              decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(ctx.scale(20)), border: Border.all(color: borderColor)),
                              child: Column(
                                children: [
                                  if (hasDiscount) ...[
                                    _billingRow(ctx, "Original Price", originalPrice, currencyFormatter, theme, isDark, isStrikethrough: true),
                                    _billingRow(ctx, "Special Discount", originalPrice - netPayable, currencyFormatter, theme, isDark, color: isDark ? Colors.greenAccent : Colors.green),
                                    Padding(padding: EdgeInsets.symmetric(vertical: ctx.scale(8)), child: Divider(height: 1, color: borderColor)),
                                  ],

                                  _billingRow(ctx, "Final Agreed Amount", netPayable, currencyFormatter, theme, isDark, isBold: true),
                                  SizedBox(height: ctx.scale(8)),
                                  _billingRow(ctx, "Amount Paid", totalPaid, currencyFormatter, theme, isDark, color: colorScheme.primary),
                                  Padding(padding: EdgeInsets.symmetric(vertical: ctx.scale(8)), child: Divider(height: 1, color: borderColor)),
                                  _billingRow(ctx, "Pending Dues", balance > 0 ? balance : 0.0, currencyFormatter, theme, isDark, color: balance > 0 ? Colors.redAccent : Colors.green, isBold: true, size: 10),
                                ],
                              ),
                            ),

                            // 💳 4. TRANSACTION HISTORY
                            if (payments.isNotEmpty) ...[
                              SizedBox(height: ctx.scale(24)),
                              _sectionHeader(ctx, "TRANSACTION HISTORY", Icons.receipt_long_rounded, colorScheme, isDark),
                              ...payments.map((p) {
                                final String mode = (p.paymentMethod ?? 'Online').toUpperCase();

                                return Container(
                                  margin: EdgeInsets.only(bottom: ctx.scale(10)),
                                  padding: EdgeInsets.symmetric(horizontal: ctx.scale(16), vertical: ctx.scale(12)),
                                  decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(ctx.scale(16)), border: Border.all(color: borderColor)),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(ctx.scale(10)),
                                        decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                                        child: Icon(_getPaymentIcon(mode), color: colorScheme.primary, size: ctx.scale(16)),
                                      ),
                                      SizedBox(width: ctx.scale(12)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(mode, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: ctx.scale(11), color: colorScheme.onSurface, letterSpacing: ctx.scale(0.5))),
                                            SizedBox(height: ctx.scale(2)),
                                            Text(DateFormat('MMM dd, yyyy').format(p.paymentDate), style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: ctx.scale(10), fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Text(currencyFormatter.format(p.amount), style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: ctx.scale(10), color: colorScheme.onSurface)),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        );
                      },
                    ),
                    SizedBox(height: ctx.scale(40)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // 🛠️ HELPER WIDGETS
  // =================================================================

  Widget _sectionHeader(BuildContext context, String title, IconData icon, ColorScheme cs, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.scale(12), left: context.scale(4)),
      child: Row(
        children: [
          Icon(icon, size: context.scale(14), color: cs.primary),
          SizedBox(width: context.scale(8)),
          Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w900, letterSpacing: context.scale(1.5), color: isDark ? Colors.white70 : cs.onSurface)),
        ],
      ),
    );
  }

  Widget _billingRow(BuildContext context, String label, double amount, NumberFormat f, ThemeData theme, bool isDark, {bool isBold = false, Color? color, bool isStrikethrough = false, double size = 12}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.scale(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(10), fontWeight: FontWeight.w500)),
          Text(
              f.format(amount),
              style: TextStyle(
                fontFamily: kDisplayFont,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: color ?? theme.colorScheme.onSurface,
                fontSize: context.scale(size),
                decoration: isStrikethrough ? TextDecoration.lineThrough : null,
                decorationColor: color ?? theme.hintColor,
              )
          ),
        ],
      ),
    );
  }

  Widget _buildDateColumn(BuildContext context, String label, DateTime date, ThemeData theme, bool isDark, {bool isEnd = false}) {
    return Column(
      crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: context.scale(8), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.0))),
        SizedBox(height: context.scale(4)),
        Text(
            DateFormat('dd MMM yyyy').format(date),
            style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: context.scale(10), color: theme.colorScheme.onSurface)
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String mode) {
    if (mode.contains('UPI') || mode.contains('GPAY') || mode.contains('PAYTM') || mode.contains('PHONEPE')) return Icons.qr_code_scanner_rounded;
    if (mode.contains('CARD') || mode.contains('CREDIT') || mode.contains('DEBIT') || mode.contains('VISA')) return Icons.credit_card_rounded;
    if (mode.contains('CASH')) return Icons.payments_rounded;
    if (mode.contains('BANK') || mode.contains('NEFT') || mode.contains('RTGS')) return Icons.account_balance_rounded;
    return Icons.receipt_long_rounded;
  }

  Map<String, dynamic> _getTierStyle(String? type, ColorScheme colorScheme) {
    final String tier = (type ?? 'basic').toLowerCase();

    if (tier.contains('premium') || tier.contains('elite') || tier.contains('vip')) {
      return {'label': 'PREMIUM TIER', 'color': Colors.amber.shade700, 'bg': Colors.amber.withOpacity(0.15), 'icon': Icons.stars_rounded};
    } else if (tier.contains('standard') || tier.contains('pro') || tier.contains('advance')) {
      return {'label': 'STANDARD TIER', 'color': Colors.blue.shade700, 'bg': Colors.blue.withOpacity(0.1), 'icon': Icons.verified_user_rounded};
    } else {
      return {'label': 'BASIC TIER', 'color': Colors.teal.shade700, 'bg': Colors.teal.withOpacity(0.1), 'icon': Icons.spa_rounded};
    }
  }
}