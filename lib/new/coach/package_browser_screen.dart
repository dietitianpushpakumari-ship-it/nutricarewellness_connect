import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pure_shift/features/dietplan/domain/entities/package_model.dart';

class PackageBrowserScreen extends StatelessWidget {
  const PackageBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Themed Background
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 🎨 Glassy AppBar
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: theme.scaffoldBackgroundColor.withOpacity(0.7)),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Explore Plans", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('packages').where('isActive', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: theme.dividerColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text("No active plans available right now.", style: TextStyle(color: theme.hintColor)),
                ],
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            // 🎯 SafeArea padding for bottom navigation/home bar
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final pkg = PackageModel.fromFirestore(snapshot.data!.docs[index]);

              return Container(
                decoration: BoxDecoration(
                  color: theme.cardColor, // 🎨 Premium Glass Card
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Title & Duration Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              pkg.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: colorScheme.onSurface),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                            ),
                            child: Text(
                              "${pkg.durationDays} Days",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Description
                      Text(
                        pkg.description,
                        style: TextStyle(color: theme.hintColor, height: 1.4),
                      ),

                      const SizedBox(height: 20),
                      Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                      const SizedBox(height: 16),

                      // 3. Price & Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total Price", style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                "₹${pkg.price}",
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.greenAccent.shade400 : Colors.green.shade700
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              // Navigate to Chat with pre-filled text
                              // Example:
                              // Navigator.pop(context);
                              // chatService.sendQuickMessage("I'm interested in the ${pkg.name} plan.");
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text("Enquire", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}