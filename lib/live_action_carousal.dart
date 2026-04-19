import 'package:flutter/material.dart';

class LiveActionCarousel extends StatefulWidget {
  final String? workoutTitle;
  final String? workoutTime;
  final VoidCallback? onWorkoutTap;

  final int unreadChatCount;
  final VoidCallback onChatTap;

  final VoidCallback onBookTap;

  final String? activeNudge;

  const LiveActionCarousel({
    super.key,
    this.workoutTitle,
    this.workoutTime,
    this.onWorkoutTap,
    required this.unreadChatCount,
    required this.onChatTap,
    required this.onBookTap,
    this.activeNudge,
  });

  @override
  State<LiveActionCarousel> createState() => _LiveActionCarouselState();
}

class _LiveActionCarouselState extends State<LiveActionCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  List<Widget> _activeCards = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildActiveCards();
  }

  @override
  void didUpdateWidget(covariant LiveActionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildActiveCards();
  }

  void _buildActiveCards() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    _activeCards.clear();

    // 1. 🚨 HIGHEST PRIORITY: Live Workout
    if (widget.workoutTitle != null && widget.onWorkoutTap != null) {
      _activeCards.add(_buildCard(
        title: "Time for ${widget.workoutTitle}!",
        subtitle: widget.workoutTime ?? "Start your session now",
        icon: Icons.local_fire_department_rounded,
        color: Colors.green,
        bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        onTap: widget.onWorkoutTap!,
        actionText: "START",
      ));
    }

    // 2. 💬 HIGH PRIORITY: Unread Chat
    if (widget.unreadChatCount > 0) {
      _activeCards.add(_buildCard(
        title: "New Message from Coach",
        subtitle: "You have ${widget.unreadChatCount} unread message(s)",
        icon: Icons.forum_rounded,
        color: Colors.blueAccent,
        bgColor: isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : Colors.blue.shade50,
        onTap: widget.onChatTap,
        actionText: "REPLY",
      ));
    }

    // 3. 🔔 MEDIUM PRIORITY: Live Nudge
    if (widget.activeNudge != null) {
      _activeCards.add(_buildCard(
        title: "Coach's Nudge",
        subtitle: widget.activeNudge!,
        icon: Icons.lightbulb_rounded,
        color: Colors.orange,
        bgColor: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
        onTap: () {},
        actionText: "VIEW",
      ));
    }

    // 4. 📅 DEFAULT/LOW PRIORITY: Booking Card (Always there)
    _activeCards.add(_buildCard(
      title: "Book a Session",
      subtitle: "Schedule a 1-on-1 consultation",
      icon: Icons.calendar_month_rounded,
      color: theme.colorScheme.primary,
      bgColor: isDark ? theme.colorScheme.primary.withOpacity(0.15) : theme.colorScheme.primary.withOpacity(0.08),
      onTap: widget.onBookTap,
      actionText: "BOOK",
    ));
  }

  @override
  void dispose() {
    // 🚀 Timer is completely gone! Just clean up the controller.
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required String actionText,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text(actionText, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeCards.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 85,
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            // 🚀 This safely updates the dots when the user manually swipes
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: _activeCards,
          ),
        ),
        if (_activeCards.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _activeCards.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: _currentPage == index ? 16 : 4,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).hintColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}