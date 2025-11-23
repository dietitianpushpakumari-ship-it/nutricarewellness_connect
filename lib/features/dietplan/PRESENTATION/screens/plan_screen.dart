import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// 🎯 REMOVED: Old Wellness Sheets
// import 'package:nutricare_connect/core/utils/daily_wellness_sheet.dart';
// import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';

// 🎯 NEW: Import Sleep Detail Sheet (The Consolidated Check-in)
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';

import 'package:nutricare_connect/core/utils/diet_pdf_service.dart';
import 'package:nutricare_connect/core/utils/meal_detail_sheet.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/guidelines.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:printing/printing.dart';

class PlanScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return Center(child: Text('Error: ${state.error}'));

    final activePlan = state.activePlan;
    if (activePlan == null) return const Center(child: Text('No active diet plan assigned.'));

    final dayPlan = activePlan.days.isNotEmpty ? activePlan.days.first : null;
    final dailyLogs = state.dailyLogs;

    // Check Wellness Status
    final ClientLogModel? wellnessLog = dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
    final bool isWellnessComplete = wellnessLog != null;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE), // Clean Off-White
        body: CustomScrollView(
          slivers: [
            // 1. Header & Date Switcher
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Menu",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 20),
                              ),
                              tooltip: "Download Plan",
                              onPressed: () async {
                                if (activePlan == null) return;
                                // Generate PDF
                                final pdfData = await DietPdfService.generateDietPdf(activePlan);
                                // Share/Print
                                await Printing.sharePdf(bytes: pdfData, filename: 'My_Diet_Plan.pdf');
                              },
                            ),
                            const SizedBox(width: 8),
                            // Date Picker Button
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: state.selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) notifier.selectDate(picked);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM d').format(state.selectedDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. The "Daily Mission" (Wellness Check)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildWellnessBanner(context, isWellnessComplete, () {
                  // 🎯 UPDATE: Opens SleepDetailSheet (The Consolidated Tool)
                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SleepDetailSheet(
                        notifier: notifier,
                        activePlan: activePlan,
                        dailyLog: wellnessLog,
                      )
                  );
                }),
              ),
            ),

            // 3. The Meal Timeline
            if (dayPlan != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final meal = dayPlan.meals[index];
                      final log = dailyLogs.firstWhereOrNull((l) => l.mealName == meal.mealName);

                      return _buildMealTicket(context, meal, log, activePlan, notifier);
                    },
                    childCount: dayPlan.meals.length,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: Center(child: Text("Rest Day - No Meals Planned"))),

            // 4. Guidelines Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  "Guidelines & Tips",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
              ),
            ),

            // 5. Guidelines Horizontal Scroll
            SliverToBoxAdapter(
              child: _buildGuidelinesCarousel(context, activePlan.guidelineIds, ref),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom Padding
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Wellness Banner ---
  Widget _buildWellnessBanner(BuildContext context, bool isComplete, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isComplete
                ? [Colors.green.shade600, Colors.green.shade400]
                : [const Color(0xFF2E3A59), const Color(0xFF4B5D85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: (isComplete ? Colors.green : Colors.blueGrey).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(isComplete ? Icons.check : Icons.bedtime, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isComplete ? "Daily Check-in Complete" : "Log Sleep & Wellness",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isComplete ? "Great job staying consistent!" : "Track sleep quality, energy & mood.",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isComplete)
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Meal Ticket (No Changes) ---
  Widget _buildMealTicket(BuildContext context, DietPlanMealModel meal, ClientLogModel? log, ClientDietPlanModel activePlan, DietPlanNotifier notifier) {
    final isLogged = log != null;
    final isSkipped = log?.logStatus == LogStatus.skipped;
    final isDeviated = log?.isDeviation ?? false;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.circle_outlined;

    if (isLogged) {
      if (isSkipped) {
        statusColor = Colors.orange;
        statusIcon = Icons.do_not_disturb;
      } else if (isDeviated) {
        statusColor = Colors.red;
        statusIcon = Icons.warning_amber_rounded;
      } else {
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLogged ? Border.all(color: statusColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isLogged ? statusColor.withOpacity(0.1) : Colors.grey.shade50,
              child: Row(
                children: [
                  Icon(Icons.restaurant, size: 18, color: isLogged ? statusColor : Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    meal.mealName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isLogged ? statusColor.withOpacity(0.8) : Colors.black87
                    ),
                  ),
                  const Spacer(),
                  if (isLogged)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            isSkipped ? "Skipped" : (isDeviated ? "Deviated" : "Done"),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...meal.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.fiber_manual_record, size: 6, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${item.foodItemName} (${item.quantity} ${item.unit})",
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 16),
                  const Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isLogged && !isSkipped)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("You ate:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                  log!.actualFoodEaten.join(", "),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
                              ),
                            ],
                          ),
                        ),

                      ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => MealDetailSheet(
                              notifier: notifier,
                              mealName: meal.mealName,
                              activePlan: activePlan,
                              logToEdit: log,
                              plannedItems: meal.items,
                            ),
                          );
                        },
                        icon: Icon(isLogged ? Icons.edit : Icons.add_circle_outline, size: 16),
                        label: Text(isLogged ? "Edit Log" : "Log Meal"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLogged ? Colors.white : Theme.of(context).colorScheme.primary,
                          foregroundColor: isLogged ? Colors.black87 : Colors.white,
                          elevation: isLogged ? 0 : 2,
                          side: isLogged ? BorderSide(color: Colors.grey.shade300) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Guidelines Carousel ---
  Widget _buildGuidelinesCarousel(BuildContext context, List<String> guidelineIds, WidgetRef ref) {
    final guidelinesAsync = ref.watch(guidelineProvider(guidelineIds));

    return SizedBox(
      height: 140,
      child: guidelinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox(),
        data: (guidelines) {
          if (guidelines.isEmpty) {
            return const Center(child: Text("No specific guidelines for today.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: guidelines.length,
            itemBuilder: (context, index) {
              final guide = guidelines[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade50),
                  boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.teal.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                            "Tip #${index + 1}",
                            style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      guide.enTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}