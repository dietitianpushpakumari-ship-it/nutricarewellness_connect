import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/dashboard/analytics_detail_screen.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

// 🚀 IMPORT YOUR INTERPRETER
import 'package:pure_shift/core/utils/wellness_interpretor.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class SmartInsightCard extends ConsumerWidget {
  final String clientId;

  const SmartInsightCard({super.key, required this.clientId});

  // 🚀 SCORE COLOR ENGINE
  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF00E676); // Optimal Green
    if (score >= 50) return const Color(0xFFFFAB40); // Stable Amber
    return const Color(0xFFFF5252); // Critical Coral
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch live historical data (14 days to match the Analytics Sheet default)
    final historyAsync = ref.watch(historicalLogProvider((clientId: clientId, days: 14)));

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🚀 THE FIX: Calculate the score & records HERE so the GestureDetector can use them!
    List<ClientLogModel> dailyRecords = [];
    int wellnessScore = 0;

    if (historyAsync.hasValue && historyAsync.value != null) {
      dailyRecords = historyAsync.value!.values.cast<ClientLogModel>().toList();
      dailyRecords.sort((a, b) => a.date.compareTo(b.date));
      if (dailyRecords.isNotEmpty) {
        wellnessScore = WellnessInterpreter.calculateWellnessScore(dailyRecords);
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AnalyticsDetailSheet(
            clientId: clientId,
            initialScore: wellnessScore > 0 ? wellnessScore : null,
            initialLogs: dailyRecords.isNotEmpty ? dailyRecords : null,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: context.scale(16)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121826) : Colors.white,
          borderRadius: BorderRadius.circular(context.scale(28)),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : cs.primary.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.scale(28)),
          child: historyAsync.when(
            loading: () => _buildLoadingState(context, cs),
            error: (_, __) => _buildDefaultState(context, isDark, cs),
            data: (_) => _buildInsightContent(context, dailyRecords, wellnessScore, isDark, cs, theme),
          ),
        ),
      ),
    );
  }

  // 🚀 Updated to accept the pre-calculated dailyRecords and wellnessScore
  Widget _buildInsightContent(BuildContext context, List<ClientLogModel> dailyRecords, int wellnessScore, bool isDark, ColorScheme cs, ThemeData theme) {
    // Default State (If no data exists yet)
    String insightTitle = "Awaiting Data";
    String insightBody = "Log today's vitals to calculate your score.";

    // 🚀 LIVE CLINICAL LOGIC ENGINE
    if (dailyRecords.isNotEmpty) {
      final insights = WellnessInterpreter.generateInsights(dailyRecords);

      if (insights.isNotEmpty) {
        // Grab the #1 highest priority insight to show on the dashboard
        insightTitle = insights.first.title;
        insightBody = insights.first.message;
      } else {
        // Fallback if score is good but no specific insight triggered
        if (wellnessScore >= 80) {
          insightTitle = "Optimal Status";
          insightBody = "All vitals are in excellent ranges.";
        } else if (wellnessScore >= 50) {
          insightTitle = "Stable Status";
          insightBody = "You are maintaining a steady baseline.";
        } else {
          insightTitle = "Action Required";
          insightBody = "Review your analytics sheet for critical alerts.";
        }
      }
    }

    final Color scoreColor = _getScoreColor(wellnessScore);

    return Stack(
      children: [
        // 🚀 ADAPTIVE AURA BLOB (Color linked to actual score)
        Positioned(
          top: -40,
          left: -40,
          child: Container(
            width: context.scale(150),
            height: context.scale(150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: wellnessScore == 0 ? Colors.grey.withOpacity(0.1) : scoreColor.withOpacity(isDark ? 0.12 : 0.06),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),

        // 🚀 THE CONTENT PAYLOAD
        Padding(
          padding: EdgeInsets.all(context.scale(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- LEFT: TEXT CONTENT ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                            width: context.scale(6),
                            height: context.scale(6),
                            decoration: BoxDecoration(
                                color: wellnessScore == 0 ? theme.hintColor : scoreColor,
                                shape: BoxShape.circle
                            )
                        ),
                        SizedBox(width: context.scale(8)),
                        Text(
                          "WELLNESS SCORE",
                          style: TextStyle(
                              fontFamily: kDisplayFont,
                              fontSize: context.scale(9),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: wellnessScore == 0 ? theme.hintColor : scoreColor
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.scale(8)),
                    Text(
                      insightTitle,
                      style: TextStyle(
                          fontFamily: kDisplayFont,
                          fontSize: context.scale(18),
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.scale(4)),
                    Text(
                      insightBody,
                      style: TextStyle(
                          fontFamily: kBodyFont,
                          fontSize: context.scale(12),
                          color: theme.hintColor.withOpacity(0.8)
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              SizedBox(width: context.scale(12)),

              // --- RIGHT: COMPACT GAUGE (Watch Face) ---
              Container(
                height: context.scale(65),
                width: context.scale(65),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: context.scale(50),
                      height: context.scale(50),
                      child: CircularProgressIndicator(
                        value: wellnessScore == 0 ? 1.0 : (wellnessScore / 100),
                        strokeWidth: context.scale(4),
                        backgroundColor: (wellnessScore == 0 ? Colors.grey : scoreColor).withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(wellnessScore == 0 ? theme.dividerColor : scoreColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wellnessScore == 0 ? "--" : "$wellnessScore",
                          style: TextStyle(
                              fontFamily: kDisplayFont,
                              fontSize: context.scale(16),
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1
                          ),
                        ),
                        Text(
                          "PTS",
                          style: TextStyle(
                            fontFamily: kDisplayFont,
                            fontSize: context.scale(7),
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white30 : Colors.black38,
                            letterSpacing: 0.5,
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
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context, ColorScheme cs) {
    return Container(
      height: context.scale(90),
      alignment: Alignment.center,
      child: SizedBox(
        width: context.scale(24),
        height: context.scale(24),
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      ),
    );
  }

  Widget _buildDefaultState(BuildContext context, bool isDark, ColorScheme cs) {
    return Container(
      height: context.scale(90),
      alignment: Alignment.center,
      child: Text(
        "No historical data available.",
        style: TextStyle(fontFamily: kBodyFont, color: isDark ? Colors.white54 : Colors.black54, fontSize: context.scale(13)),
      ),
    );
  }
}