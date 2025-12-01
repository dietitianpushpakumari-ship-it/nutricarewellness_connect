import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/meeting_Service.dart';


class AdminSchedulerScreen extends StatefulWidget {
  const AdminSchedulerScreen({super.key});

  @override
  State<AdminSchedulerScreen> createState() => _AdminSchedulerScreenState();
}

class _AdminSchedulerScreenState extends State<AdminSchedulerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MeetingService _service = MeetingService();

  // Generator State
  DateTime _selectedDay = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);

  // Lock State
  DateTimeRange? _lockRange;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // 1. Create Availability
  Future<void> _generate() async {
    List<DateTime> slots = [];
    DateTime current = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, _start.hour, _start.minute);
    DateTime endDt = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, _end.hour, _end.minute);

    while (current.isBefore(endDt)) {
      slots.add(current);
      current = current.add(const Duration(minutes: 15)); // Always generate base 15s
    }
    await _service.createSlots(slots);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Created ${slots.length} slots")));
  }

  // 2. Lock Range
  Future<void> _lock() async {
    if (_lockRange == null || _reasonCtrl.text.isEmpty) return;
    await _service.lockTimeRange(_lockRange!.start, _lockRange!.end, _reasonCtrl.text);
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Range Locked Successfully")));
      _reasonCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(title: const Text("Manage Schedule"), bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "Create Slots"), Tab(text: "Emergency Lock")])),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Generator
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCard(child: Column(
                  children: [
                    ListTile(title: const Text("Date"), trailing: Text(DateFormat('dd MMM').format(_selectedDay)), onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _selectedDay, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                      if(d!=null) setState(()=>_selectedDay=d);
                    }),
                    ElevatedButton(onPressed: _generate, child: const Text("Generate 9-5 Slots"))
                  ],
                )),
                const Divider(),
                const Expanded(child: Center(child: Text("Existing slots list here...")))
              ],
            ),
          ),

          // Tab 2: Lock
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCard(child: Column(
                  children: [
                    const Text("Block Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListTile(
                      title: const Text("Select Range"),
                      subtitle: Text(_lockRange == null ? "Tap to pick" : "${DateFormat('dd MMM').format(_lockRange!.start)} - ${DateFormat('dd MMM').format(_lockRange!.end)}"),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final r = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2026));
                        if(r!=null) setState(()=>_lockRange = r);
                      },
                    ),
                    TextField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: "Reason (e.g. Holiday)")),
                    const SizedBox(height: 20),
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: _lock, child: const Text("LOCK RANGE"))
                  ],
                ))
              ],
            ),
          )
        ],
      ),
    );
  }
  Widget _buildCard({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: child);
}