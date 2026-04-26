import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/timetable_entry.dart';
import '../../services/db_service.dart';

class FacultyScheduleManagerScreen extends StatefulWidget {
  final String facultyPnr;
  const FacultyScheduleManagerScreen({super.key, required this.facultyPnr});

  @override
  State<FacultyScheduleManagerScreen> createState() =>
      _FacultyScheduleManagerScreenState();
}

class _FacultyScheduleManagerScreenState
    extends State<FacultyScheduleManagerScreen> {
  DateTime _selectedDate = DateTime.now();

  String _dateKeyFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dayNameFromDate(DateTime date) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(date.weekday - 1).clamp(0, 6)];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _dateKeyFromDate(_selectedDate);
    final selectedDay = _dayNameFromDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Manager'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(
              DateFormat('MMM d').format(_selectedDate),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: DatabaseService().getTimetableForFaculty(widget.facultyPnr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final schedule = snapshot.data ?? const <TimetableEntry>[];
          final entriesForSelectedDate = schedule
              .where((e) => e.day.toLowerCase() == selectedDay.toLowerCase())
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$selectedDay • $dateKey',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (entriesForSelectedDate.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No lectures for this date.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
              ...entriesForSelectedDate.map((entry) {
                final isPractical = entry.batchName != null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.class_),
                    title: Text(
                      entry.subject,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${entry.className}${isPractical ? ' • Batch ${entry.batchName}' : ''}\n${entry.startTime} - ${entry.endTime}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

