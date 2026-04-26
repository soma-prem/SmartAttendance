import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/timetable_entry.dart';
import '../../services/db_service.dart';
import '../../services/timetable_pdf_service.dart';
import '../../utils/skeleton.dart';

class TimetableTableView extends StatefulWidget {
  final String branch;
  final int year;
  final int semester;
  final bool isAdmin;

  const TimetableTableView({
    super.key,
    required this.branch,
    required this.year,
    required this.semester,
    this.isAdmin = false,
  });

  @override
  State<TimetableTableView> createState() => _TimetableTableViewState();
}

class _TimetableTableViewState extends State<TimetableTableView> {
  final _db = DatabaseService();
  List<TimetableEntry> _timetable = [];
  bool _isLoading = true;
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTimetableBySemester(
        widget.branch,
        widget.year,
        widget.semester,
      );
      setState(() {
        _timetable = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('WITClassroom')),
        body: const SkeletonListView(itemCount: 10),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('WITClassroom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_rounded),
            tooltip: 'Download PDF',
            onPressed: () async {
              if (_timetable.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No timetable entries found')),
                );
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                await TimetablePdfService.generateAndDownloadTimetable(
                  branch: widget.branch,
                  year: widget.year,
                  semester: widget.semester,
                  timetable: _timetable,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF download failed: $e')),
                  );
                }
              } finally {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(150),
            border: TableBorder.all(color: Colors.grey[300]!, width: 1),
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                children: [
                  _buildHeaderCell('Time'),
                  ..._days.map((day) => _buildHeaderCell(day)),
                ],
              ),
              // Data Rows (We'll simplify by grouping time slots)
              ..._buildTimeRows(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<TableRow> _buildTimeRows() {
    // 1. Get all unique start times
    final allTimes = _timetable.map((e) => e.startTime).toSet().toList();
    allTimes.sort((a, b) {
      try {
        return DateFormat(
          'hh:mm a',
        ).parse(a).compareTo(DateFormat('hh:mm a').parse(b));
      } catch (_) {
        return 0;
      }
    });

    if (allTimes.isEmpty) {
      return [
        const TableRow(
          children: [
            TableCell(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No entries found'),
                ),
              ),
            ),
          ],
        ),
      ];
    }

    return allTimes.map((time) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          ..._days.map((day) {
            final entries = _timetable
                .where(
                  (e) =>
                      e.day.toLowerCase() == day.toLowerCase() &&
                      e.startTime == time,
                )
                .toList();

            if (entries.isEmpty) return const TableCell(child: SizedBox());

            return TableCell(
              child: InkWell(
                onTap: () => _showEntryDetails(entries),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: entries.any((e) => e.batchName != null)
                        ? Colors.orange[50]
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: entries
                        .map(
                          (e) => Text(
                            e.batchName != null
                                ? '${e.subject} (${e.batchName})'
                                : e.subject,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: entries.any((en) => en.batchName != null)
                                  ? Colors.orange[900]
                                  : Colors.blue[900],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }).toList();
  }

  void _showEntryDetails(List<TimetableEntry> entries) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          entries.length > 1 ? 'Practical Batches' : 'Lecture Details',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: entries.map((e) => _buildDetailItem(e)).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(TimetableEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.subject,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (e.batchName != null)
            Text(
              'Batch: ${e.batchName}',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          const Divider(),
          Text('Faculty: ${e.facultyName}'),
          Text('Time: ${e.startTime} - ${e.endTime}'),
          Text('Class: ${e.className}'),
          if (widget.isAdmin) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditDialog(e);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(TimetableEntry entry) {
    final subjectController = TextEditingController(text: entry.subject);
    final startTimeController = TextEditingController(text: entry.startTime);
    final endTimeController = TextEditingController(text: entry.endTime);
    final facultyPnrController = TextEditingController(text: entry.facultyPnr);
    final facultyNameController = TextEditingController(
      text: entry.facultyName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              TextField(
                controller: startTimeController,
                decoration: const InputDecoration(labelText: 'Start Time'),
              ),
              TextField(
                controller: endTimeController,
                decoration: const InputDecoration(labelText: 'End Time'),
              ),
              TextField(
                controller: facultyPnrController,
                decoration: const InputDecoration(labelText: 'Faculty PNR'),
              ),
              TextField(
                controller: facultyNameController,
                decoration: const InputDecoration(labelText: 'Faculty Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = TimetableEntry(
                id: entry.id,
                day: entry.day,
                startTime: startTimeController.text,
                endTime: endTimeController.text,
                subject: subjectController.text,
                facultyPnr: facultyPnrController.text,
                facultyName: facultyNameController.text,
                className: entry.className,
                batchName: entry.batchName,
                semesterNumber: entry.semesterNumber,
                year: entry.year,
                branch: entry.branch,
                createdAt: entry.createdAt,
                updatedAt: DateTime.now(),
              );
              await _db.updateTimetableEntry(entry.id, updated);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
