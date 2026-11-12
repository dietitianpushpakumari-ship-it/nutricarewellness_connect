import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pure_shift/layout_utils.dart'; // Adjust import to your actual layout_utils path

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class ClinicalServicesSheet extends StatelessWidget {
  const ClinicalServicesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final services = [
      {"title": "Weight Management", "desc": "Sustainable fat loss & metabolic reset.", "icon": Icons.monitor_weight_rounded, "color": Colors.orangeAccent},
      {"title": "Weight Gain & Muscle", "desc": "High-protein therapeutic meal planning.", "icon": Icons.fitness_center_rounded, "color": Colors.deepOrangeAccent},
      {"title": "Diabetes Care (Type 1 & 2)", "desc": "Glycemic control & HbA1c reversal support.", "icon": Icons.bloodtype_rounded, "color": Colors.redAccent},
      {"title": "PCOS & Hormonal Care", "desc": "Anti-inflammatory & insulin stabilization.", "icon": Icons.spa_rounded, "color": Colors.pinkAccent},
      {"title": "Thyroid Disorders", "desc": "Metabolic support & energy restoration.", "icon": Icons.medical_information_rounded, "color": Colors.purpleAccent},
      {"title": "Renal & Dialysis Diet", "desc": "Electrolyte & protein-optimized renal support.", "icon": Icons.water_drop_rounded, "color": Colors.blueAccent},
      {"title": "Pregnancy & Lactation", "desc": "Antenatal care & gestational diabetes management.", "icon": Icons.pregnant_woman_rounded, "color": Colors.lightBlueAccent},
      {"title": "Pediatric & Child Growth", "desc": "Immunity-boosting meals & adolescent growth.", "icon": Icons.child_care_rounded, "color": Colors.greenAccent},
      {"title": "Cardiac & Hypertension", "desc": "Low-sodium DASH diet & cholesterol reduction.", "icon": Icons.favorite_rounded, "color": Colors.red},
      {"title": "Gut Health & IBS", "desc": "Low-FODMAP protocols & chronic acidity relief.", "icon": Icons.local_dining_rounded, "color": Colors.lightGreen},
      {"title": "Liver & Fatty Liver", "desc": "Hepatic detox & low-glycemic liver protection.", "icon": Icons.health_and_safety_rounded, "color": Colors.teal},
      {"title": "Post-Surgical & Oncology", "desc": "Wound healing & weight-loss prevention.", "icon": Icons.healing_rounded, "color": Colors.indigoAccent},
      {"title": "Geriatric & Senior Care", "desc": "Bone density support & age-related vitality.", "icon": Icons.elderly_rounded, "color": Colors.brown},
      {"title": "Corporate Wellness", "desc": "Executive lifestyle plans & preventive health.", "icon": Icons.business_center_rounded, "color": Colors.blueGrey},
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(32))),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1218).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: CustomScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Drag Handle & Header
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: context.scale(12)),
                        Container(width: context.scale(40), height: context.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(context.scale(2)))),
                        Padding(
                          padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(20), context.scale(24), context.scale(16)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Clinical Services", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(22), fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close_rounded, color: theme.hintColor),
                                style: IconButton.styleFrom(backgroundColor: theme.dividerColor.withOpacity(0.05)),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. The Therapeutic Quote
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: context.scale(20), vertical: context.scale(8)),
                      padding: EdgeInsets.all(context.scale(20)),
                      decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(context.scale(16))),
                      child: Column(
                        children: [
                          Icon(Icons.format_quote_rounded, color: colorScheme.primary.withOpacity(0.5), size: context.scale(28)),
                          SizedBox(height: context.scale(8)),
                          Text(
                            "Let food be thy medicine, and medicine be thy food.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                          ),
                          SizedBox(height: context.scale(8)),
                          Text("— Hippocrates", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), color: theme.hintColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                  // 3. The 14 Services Grid
                  SliverPadding(
                    padding: EdgeInsets.all(context.scale(20)),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final service = services[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: context.scale(12)),
                            padding: EdgeInsets.all(context.scale(16)),
                            decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                                borderRadius: BorderRadius.circular(context.scale(16)),
                                border: Border.all(color: theme.dividerColor.withOpacity(0.06)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0 : 0.02), blurRadius: 10, offset: const Offset(0, 4))
                                ]
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(context.scale(14)),
                                  decoration: BoxDecoration(color: (service['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(context.scale(12))),
                                  child: Icon(service['icon'] as IconData, color: service['color'] as Color, size: context.scale(22)),
                                ),
                                SizedBox(width: context.scale(16)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(service['title'] as String, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                                      SizedBox(height: context.scale(4)),
                                      Text(service['desc'] as String, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), color: theme.hintColor, height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: services.length,
                      ),
                    ),
                  ),
                  SliverPadding(padding: EdgeInsets.only(bottom: context.scale(40))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}