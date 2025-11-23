import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';

class ActivePackageCard extends ConsumerWidget {
  final String clientId;
  const ActivePackageCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageAsync = ref.watch(assignedPackageProvider(clientId));

    return packageAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox(),
      data: (assignments) {
        final active = assignments.firstWhere((a) => a.isActive, orElse: () => assignments.first);
        if (!active.isActive) return const SizedBox(); // Don't show if no active plan

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFFD700)]), // Gold Gradient
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(active.packageName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                    child: const Text("ACTIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Valid Until", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(DateFormat.yMMMd().format(active.expiryDate), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}