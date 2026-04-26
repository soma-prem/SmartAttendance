import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_record.dart';
import '../../models/user_model.dart';
import '../../services/attendance_pdf_service.dart';
import '../../services/db_service.dart';
import '../../utils/skeleton.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String facultyPnr;
  const AttendanceHistoryScreen({super.key, required this.facultyPnr});

  @override
  AttendanceHistoryScreenState createState() => AttendanceHistoryScreenState();
}

class AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final Set<String> _selectedWeekKeys = {};
  bool _isDownloading = false;
  List<AttendanceRecord> _latestRecords = [];

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  String _formatDateTime(DateTime date) => DateFormat('MMM d, yyyy hh:mm a').format(date);

  DateTime _weekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  String _weekKey(DateTime date) => DateFormat('yyyy-MM-dd').format(_weekStart(date));

  String _weekLabel(DateTime date) {
    final start = _weekStart(date);
    final end = start.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
  }

  String _timeSlot(AttendanceRecord r) {
    final s = (r.startTime ?? '').trim();
    final e = (r.endTime ?? '').trim();
    if (s.isEmpty || e.isEmpty) return '';
    return '$s - $e';
  }

  Future<void> openDownloadDialog() async {
    final records = _latestRecords;
    if (records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attendance records available for download.')),
        );
      }
      return;
    }

    final availableWeeks = _extractWeeks(records);
    final selectedKeys = Set<String>.from(_selectedWeekKeys);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Download Attendance Report'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Select one or more weeks to include in the PDF report.'),
                    const SizedBox(height: 16),
                    if (availableWeeks.isEmpty)
                      const Text('No weekly attendance records found.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableWeeks.map((weekStart) {
                          final key = _weekKey(weekStart);
                          return FilterChip(
                            label: Text(_weekLabel(weekStart)),
                            selected: selectedKeys.contains(key),
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) {
                                  selectedKeys.add(key);
                                } else {
                                  selectedKeys.remove(key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedKeys.isEmpty
                      ? null
                      : () async {
                          Navigator.of(dialogContext).pop();
                          setState(() {
                            _selectedWeekKeys
                              ..clear()
                              ..addAll(selectedKeys);
                          });
                          await _downloadSelectedWeeks(records, selectedKeys);
                        },
                  child: const Text('Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DateTime> _extractWeeks(List<AttendanceRecord> records) {
    final weeks = records.map((r) => _weekStart(r.date)).toSet().toList();
    weeks.sort((a, b) => b.compareTo(a));
    return weeks;
  }

  Future<void> _downloadSelectedWeeks(
    List<AttendanceRecord> records,
    Set<String> selectedWeekKeys,
  ) async {
    final selectedRecords = records
        .where((r) => selectedWeekKeys.contains(_weekKey(r.date)))
        .toList();

    if (selectedRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No records found for selected weeks.')),
        );
      }
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final weekStarts = selectedRecords
          .map((r) => _weekStart(r.date))
          .toSet()
          .toList()
        ..sort();
      final periodLabel = weekStarts.length == 1
          ? _weekLabel(weekStarts.first)
          : '${_weekLabel(weekStarts.last)} to ${_weekLabel(weekStarts.first)}';

      final students = await _loadStudentsForRecords(selectedRecords);
      await AttendancePdfService.generateAndDownloadAttendanceReport(
        facultyPnr: widget.facultyPnr,
        facultyName: selectedRecords.first.facultyName,
        title: 'Attendance Report',
        periodLabel: periodLabel,
        records: selectedRecords,
        students: students,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<List<AppUser>> _loadStudentsForRecords(List<AttendanceRecord> records) async {
    final pnrMap = <String, AppUser>{};
    final classRecords = <String, AttendanceRecord>{};
    for (final record in records) {
      classRecords.putIfAbsent(record.className, () => record);
    }

    for (final record in classRecords.values) {
      final students = await DatabaseService().getStudentsByClass(
        record.className,
        semester: record.semesterNumber,
        branch: record.branch,
        year: record.year.toString(),
        batch: (record.batchKey).trim().isEmpty ? null : record.batchKey,
      );
      for (final student in students) {
        pnrMap[student.pnr] = student;
      }
    }

    if (pnrMap.isEmpty) {
      final keys = records
          .expand((r) => r.records.keys)
          .toSet()
          .map((pnr) => AppUser(pnr: pnr, name: pnr, role: 'student'))
          .toList();
      return keys;
    }

    return pnrMap.values.toList();
  }

  Future<void> _confirmDelete(BuildContext context, AttendanceRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete attendance?'),
        content: Text(
          'This will delete the attendance record for:\n'
          '${r.subject} • ${r.className}\n'
          '${_formatDate(r.date)} ${_timeSlot(r)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService().deleteAttendanceRecord(r.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance deleted')),
      );
    }
  }

  Widget _buildWeekChips(List<DateTime> weeks) {
    if (weeks.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: weeks.map((weekStart) {
        final key = _weekKey(weekStart);
        return FilterChip(
          label: Text(_weekLabel(weekStart)),
          selected: _selectedWeekKeys.contains(key),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedWeekKeys.add(key);
              } else {
                _selectedWeekKeys.remove(key);
              }
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: DatabaseService().watchAttendanceHistoryForFaculty(widget.facultyPnr),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonListView(itemCount: 10);
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final records = snapshot.data ?? const <AttendanceRecord>[];
        _latestRecords = records;

        if (records.isEmpty) {
          return const Center(child: Text('No attendance history found.'));
        }

        final weeks = _extractWeeks(records);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Attendance History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : openDownloadDialog,
                  icon: const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Preparing...' : 'Download'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (weeks.isNotEmpty) ...[
              const Text('Select weeks'),
              const SizedBox(height: 10),
              _buildWeekChips(weeks),
              const SizedBox(height: 18),
            ],
            ...records.map((r) {
              final timeSlot = _timeSlot(r);
              final detailLines = <String>[
                '${r.branch} • Year ${r.year} • Sem ${r.semesterNumber}',
                if ((r.batchKey).trim().isNotEmpty) 'Batch ${r.batchKey}',
                '${_formatDate(r.date)}${timeSlot.isEmpty ? '' : ' • $timeSlot'}',
              ];
              if (r.updatedAt != null && r.updatedAt != r.createdAt) {
                detailLines.add('Updated: ${_formatDateTime(r.updatedAt!)}');
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ListTile(
                    title: Text('${r.subject} • ${r.className}'),
                    subtitle: Text(detailLines.join('\n')),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') {
                          await _confirmDelete(context, r);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceRecordDetailScreen(record: r),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class AttendanceRecordDetailScreen extends StatefulWidget {
  final AttendanceRecord record;
  const AttendanceRecordDetailScreen({super.key, required this.record});

  @override
  State<AttendanceRecordDetailScreen> createState() =>
      _AttendanceRecordDetailScreenState();
}

class _AttendanceRecordDetailScreenState
    extends State<AttendanceRecordDetailScreen> {
  bool _loading = true;
  String? _error;
  List<AppUser> _present = [];
  List<AppUser> _absent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<AppUser> _sortByRoll(List<AppUser> users) {
    final list = [...users];
    list.sort((a, b) {
      final ra = int.tryParse((a.rollNo ?? '').trim());
      final rb = int.tryParse((b.rollNo ?? '').trim());
      if (ra != null && rb != null) return ra.compareTo(rb);
      if (ra != null) return -1;
      if (rb != null) return 1;
      return (a.rollNo ?? '').compareTo(b.rollNo ?? '');
    });
    return list;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _present = [];
      _absent = [];
    });

    try {
      final r = widget.record;
      final students = await DatabaseService().getStudentsByClass(
        r.className,
        semester: r.semesterNumber,
        branch: r.branch,
        year: r.year.toString(),
        batch: (r.batchKey).trim().isEmpty ? null : r.batchKey,
      );

      final present = <AppUser>[];
      final absent = <AppUser>[];
      for (final s in students) {
        final status = r.records[s.pnr] ?? 'Absent';
        if (status == 'Present') {
          present.add(s);
        } else {
          absent.add(s);
        }
      }

      if (!mounted) return;
      setState(() {
        _present = _sortByRoll(present);
        _absent = _sortByRoll(absent);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteRecord() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete attendance?'),
        content: const Text('This will permanently delete this attendance record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService().deleteAttendanceRecord(widget.record.id);
    if (mounted) Navigator.pop(context);
  }

  Widget _studentTile(AppUser u) {
    return ListTile(
      dense: true,
      title: Text(u.name),
      subtitle: Text('Roll: ${u.rollNo ?? '-'} • PNR: ${u.pnr}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final date = DateFormat('MMM d, yyyy').format(r.date);
    final time = [
      (r.startTime ?? '').trim(),
      (r.endTime ?? '').trim(),
    ].where((x) => x.isNotEmpty).join(' - ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteRecord,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const SkeletonListView(itemCount: 10)
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.subject,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text('${r.branch} • Year ${r.year} • Sem ${r.semesterNumber}'),
                              const SizedBox(height: 6),
                              Text('Class: ${r.className}'),
                              if (time.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Time: $time'),
                              ],
                              const SizedBox(height: 6),
                              Text('Date: $date'),
                              if (r.batchKey.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Batch: ${r.batchKey}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Present (${_present.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.green.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: _present.isEmpty
                              ? const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No students marked present.'),
                                  )
                                ]
                              : _present.map(_studentTile).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Absent (${_absent.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: _absent.isEmpty
                              ? const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No students marked absent.'),
                                  )
                                ]
                              : _absent.map(_studentTile).toList(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

