import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/timetable_entry.dart';
import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../../utils/college_data.dart';
import '../../utils/timetable_json_import.dart';

class TimetableJsonImportTab extends StatefulWidget {
  const TimetableJsonImportTab({super.key});

  @override
  State<TimetableJsonImportTab> createState() => _TimetableJsonImportTabState();
}

class _FacultySelection {
  final String pnr;
  final String name;

  const _FacultySelection({required this.pnr, required this.name});
}

class _TimetableJsonImportTabState extends State<TimetableJsonImportTab> {
  final _db = DatabaseService();
  final _jsonController = TextEditingController();

  String? _branch;
  int? _year;
  int? _semester;
  String? _division;

  DateTime? _semesterStartDate;
  DateTime? _semesterEndDate;

  bool _replaceExisting = true;
  bool _isParsing = false;
  bool _isSaving = false;

  TimetableImportData? _parsed;
  List<TimetableAssignmentKey> _assignmentKeys = [];
  final Map<String, String> _suggestedFacultyNameByKey = {};
  final Map<String, _FacultySelection> _facultySelectionByKey = {};

  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pickJsonFile() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
    );
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    try {
      String text = '';
      if (file.bytes != null) {
        text = utf8.decode(file.bytes!);
      } else {
        throw Exception('File bytes not available. Please re-pick with storage permission, or paste JSON.');
      }
      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file content.')),
        );
        return;
      }
      setState(() {
        _jsonController.text = text;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File read failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickDate({
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_semesterStartDate ?? now)
        : (_semesterEndDate ?? _semesterStartDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _semesterStartDate = picked;
      } else {
        _semesterEndDate = picked;
      }
    });
  }

  void _parseAndPreview() {
    final branch = _branch?.trim().toUpperCase();
    final year = _year;
    final semester = _semester;
    final division = _division?.trim().toUpperCase();

    if (branch == null ||
        branch.isEmpty ||
        year == null ||
        semester == null ||
        division == null ||
        division.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select branch, year, semester, and division first.')),
      );
      return;
    }

    final text = _jsonController.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste JSON or pick a file first.')),
      );
      return;
    }

    setState(() => _isParsing = true);
    try {
      final parsed = parseTimetableImportJson(text);

      // Build assignment keys (skip "-")
      final keys = <TimetableAssignmentKey>{};
      final suggested = <String, String>{};

      for (final s in parsed.slots) {
        final rawSubject = s.subjectName.trim();
        if (rawSubject.isEmpty || rawSubject == '-') continue;
        if (!_days.contains(s.day.trim())) {
          throw FormatException('Invalid day "${s.day}" in slots. Allowed: ${_days.join(', ')}');
        }

        final subjects = splitTutSubjects(rawSubject);
        for (final subject in subjects) {
          if (subject.trim().isEmpty) continue;
          final key = s.type == 'PRACTICAL'
              ? TimetableAssignmentKey(subjectName: subject, batchName: s.batch)
              : TimetableAssignmentKey(subjectName: subject);
          keys.add(key);
        }
      }

      setState(() {
        _parsed = parsed;
        _assignmentKeys = keys.toList()
          ..sort((a, b) {
            final s = a.subjectName.compareTo(b.subjectName);
            if (s != 0) return s;
            return (a.batchName ?? '').compareTo(b.batchName ?? '');
          });
        _suggestedFacultyNameByKey
          ..clear()
          ..addAll(suggested);
        _isParsing = false;
      });
    } catch (e) {
      setState(() => _isParsing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parse failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  int _minutesFromDisplayTime(String value) {
    final dt = DateFormat('hh:mm a').parse(value);
    return dt.hour * 60 + dt.minute;
  }

  void _validateNoOverlaps(List<TimetableEntry> entries) {
    final batches = entries
        .map((e) => e.batchName)
        .where((b) => b != null && b.trim().isNotEmpty)
        .map((b) => b!.trim())
        .toSet()
        .toList()
      ..sort();

    for (final day in _days) {
      final lectures = entries.where((e) => e.day == day && e.batchName == null).toList();

      // Validate lectures alone
      _assertNoOverlapForGroup(day: day, label: 'Lecture', entries: lectures);

      // Validate effective schedule for each batch: lectures + that batch practicals
      for (final batch in batches) {
        final practicals =
            entries.where((e) => e.day == day && e.batchName == batch).toList();
        _assertNoOverlapForGroup(
          day: day,
          label: batch,
          entries: [...lectures, ...practicals],
        );
      }
    }
  }

  void _assertNoOverlapForGroup({
    required String day,
    required String label,
    required List<TimetableEntry> entries,
  }) {
    if (entries.length <= 1) return;
    final sorted = [...entries]..sort((a, b) {
      final am = _minutesFromDisplayTime(a.startTime);
      final bm = _minutesFromDisplayTime(b.startTime);
      if (am != bm) return am.compareTo(bm);
      return _minutesFromDisplayTime(a.endTime).compareTo(_minutesFromDisplayTime(b.endTime));
    });

    int? prevEnd;
    TimetableEntry? prev;
    for (final e in sorted) {
      final start = _minutesFromDisplayTime(e.startTime);
      final end = _minutesFromDisplayTime(e.endTime);
      if (end <= start) {
        throw Exception('Invalid time range on $day for $label: ${e.subject} (${e.startTime}-${e.endTime})');
      }
      if (prevEnd != null && start < prevEnd) {
        final p = prev!;
        throw Exception(
          'Overlap on $day for $label: '
          '${p.subject} (${p.startTime}-${p.endTime}) overlaps with '
          '${e.subject} (${e.startTime}-${e.endTime}).',
        );
      }
      prevEnd = end;
      prev = e;
    }
  }

  List<TimetableEntry> _buildEntries({
    required TimetableImportData data,
    required String branch,
    required int year,
    required int semester,
    required String division,
  }) {
    final className = '$branch-$division';
    final entries = <TimetableEntry>[];

    final slotsByDay = <String, List<TimetableImportSlot>>{};
    for (final s in data.slots) {
      slotsByDay.putIfAbsent(s.day.trim(), () => []).add(s);
    }

    for (final day in _days) {
      final daySlots = slotsByDay[day] ?? const <TimetableImportSlot>[];
      int? cursor;

      for (final slot in daySlots) {
        final rawSubject = slot.subjectName.trim();
        if (rawSubject.isEmpty || rawSubject == '-') continue;

        final start = convertLooseHhMmToDisplay(
          hhmm: slot.startTime,
          previousMinutes: cursor,
        );
        final end = convertLooseHhMmToDisplay(
          hhmm: slot.endTime,
          previousMinutes: start.minutes,
        );
        cursor = (cursor == null)
            ? end.minutes
            : (end.minutes > cursor ? end.minutes : cursor);

        final subjects = splitTutSubjects(rawSubject);
        if (rawSubject.toUpperCase().contains('(TUT)') &&
            rawSubject.contains('/') &&
            subjects.length == 2) {
          final duration = end.minutes - start.minutes;
          if (duration != 120) {
            throw Exception(
              'Tutorial slot must be exactly 2 hours to split into 1+1: '
              '$rawSubject on $day (${slot.startTime}-${slot.endTime}).',
            );
          }

          final midMinutes = start.minutes + 60;
          final midDt = DateTime(2000, 1, 1, midMinutes ~/ 60, midMinutes % 60);
          final midFormatted = DateFormat('hh:mm a').format(midDt);

          for (var i = 0; i < 2; i++) {
            final subject = subjects[i].trim();
            final key = slot.type == 'PRACTICAL'
                ? TimetableAssignmentKey(subjectName: subject, batchName: slot.batch)
                : TimetableAssignmentKey(subjectName: subject);
            final selected = _facultySelectionByKey[key.id];
            if (selected == null) {
              throw Exception(
                'Faculty not selected for ${key.subjectName}${key.isPractical ? ' (${key.batchName})' : ''}.',
              );
            }

            entries.add(
              TimetableEntry(
                id: 'tmp_${entries.length}',
                day: day,
                startTime: i == 0 ? start.formatted : midFormatted,
                endTime: i == 0 ? midFormatted : end.formatted,
                subject: subject,
                facultyPnr: selected.pnr,
                facultyName: selected.name,
                className: className,
                batchName: key.isPractical ? key.batchName!.trim() : null,
                semesterNumber: semester,
                year: year,
                branch: branch,
                createdAt: DateTime.now(),
              ),
            );
          }
        } else {
          // Normal slot (single subject)
          final subject = subjects.first.trim();
          final key = slot.type == 'PRACTICAL'
              ? TimetableAssignmentKey(subjectName: subject, batchName: slot.batch)
              : TimetableAssignmentKey(subjectName: subject);
          final selected = _facultySelectionByKey[key.id];
          if (selected == null) {
            throw Exception(
              'Faculty not selected for ${key.subjectName}${key.isPractical ? ' (${key.batchName})' : ''}.',
            );
          }

          entries.add(
            TimetableEntry(
              id: 'tmp_${entries.length}',
              day: day,
              startTime: start.formatted,
              endTime: end.formatted,
              subject: subject,
              facultyPnr: selected.pnr,
              facultyName: selected.name,
              className: className,
              batchName: key.isPractical ? key.batchName!.trim() : null,
              semesterNumber: semester,
              year: year,
              branch: branch,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    return entries;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final parsed = _parsed;
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parse JSON first.')),
      );
      return;
    }

    final branch = _branch?.trim().toUpperCase();
    final year = _year;
    final semester = _semester;
    final division = _division?.trim().toUpperCase();
    final start = _semesterStartDate;
    final end = _semesterEndDate;

    if (branch == null ||
        branch.isEmpty ||
        year == null ||
        semester == null ||
        division == null ||
        division.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select branch, year, semester, and division.')),
      );
      return;
    }
    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick semester start and end dates.')),
      );
      return;
    }
    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semester end date cannot be before start date.')),
      );
      return;
    }

    // Ensure every key has a faculty selected
    for (final key in _assignmentKeys) {
      if (_facultySelectionByKey[key.id] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Select faculty for ${key.subjectName}${key.isPractical ? ' (${key.batchName})' : ''}.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final entries = _buildEntries(
        data: parsed,
        branch: branch,
        year: year,
        semester: semester,
        division: division,
      );

      _validateNoOverlaps(entries);

      final className = '$branch-$division';
      if (_replaceExisting) {
        await _db.deleteTimetableForClassSemester(
          branch: branch,
          year: year,
          semesterNumber: semester,
          className: className,
        );
      }

      await _db.setSemesterWindow(branch, year, semester, start, end);
      await _db.addBulkTimetableEntries(entries);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${entries.length} entries for $className.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<_FacultySelection?> _showFacultySearchDialog({
    required List<AppUser> faculty,
    _FacultySelection? current,
  }) async {
    return showDialog<_FacultySelection>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        final controller = TextEditingController();

        List<AppUser> filtered() {
          final q = query.trim().toLowerCase();
          if (q.isEmpty) return faculty;
          return faculty.where((f) {
            final name = f.name.toLowerCase();
            final pnr = f.pnr.toLowerCase();
            return name.contains(q) || pnr.contains(q);
          }).toList();
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final list = filtered();
            return AlertDialog(
              title: const Text('Select Faculty'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search by name or PNR',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: list.isEmpty
                          ? const Center(child: Text('No matching faculty.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: list.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final f = list[index];
                                final isSelected =
                                    current?.pnr.trim() == f.pnr.trim();
                                return ListTile(
                                  dense: true,
                                  title: Text(f.name.trim().isEmpty ? '(No name)' : f.name.trim()),
                                  subtitle: Text(f.pnr.trim()),
                                  trailing: isSelected
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : null,
                                  onTap: () {
                                    Navigator.of(dialogContext).pop(
                                      _FacultySelection(
                                        pnr: f.pnr.trim(),
                                        name: f.name.trim(),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final divisions = CollegeData.divisionsForYear(_year);
    final hasParsed = _parsed != null && _assignmentKeys.isNotEmpty;
    final classNamePreview = (_branch != null &&
            (_division ?? '').trim().isNotEmpty)
        ? '${_branch!.trim().toUpperCase()}-${_division!.trim().toUpperCase()}'
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Import Timetable from JSON',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _branch,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Branch',
              border: OutlineInputBorder(),
            ),
            items: CollegeData.branches
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: _isSaving ? null : (v) => setState(() => _branch = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  items: CollegeData.years
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() {
                            _year = v;
                            final nextDivisions = CollegeData.divisionsForYear(v);
                            final current = (_division ?? '').trim().toUpperCase();
                            if (current.isNotEmpty &&
                                !nextDivisions.contains(current)) {
                              _division = null;
                            }
                          }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _semester,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                  ),
                  items: CollegeData.semesters
                      .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                      .toList(),
                  onChanged: _isSaving ? null : (v) => setState(() => _semester = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _division,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Division',
              border: OutlineInputBorder(),
            ),
            items: divisions
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: _isSaving ? null : (v) => setState(() => _division = v),
          ),
          if (classNamePreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Class: $classNamePreview', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _pickDate(isStart: true),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _semesterStartDate == null
                        ? 'Start Date'
                        : DateFormat('dd-MMM-yyyy').format(_semesterStartDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _pickDate(isStart: false),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _semesterEndDate == null
                        ? 'End Date'
                        : DateFormat('dd-MMM-yyyy').format(_semesterEndDate!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _pickJsonFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick JSON File'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _parsed = null;
                            _assignmentKeys = [];
                            _suggestedFacultyNameByKey.clear();
                            _facultySelectionByKey.clear();
                          });
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear Preview'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _jsonController,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Timetable JSON',
              border: OutlineInputBorder(),
              hintText: 'Paste JSON here or pick a file above...',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isParsing || _isSaving) ? null : _parseAndPreview,
                  icon: _isParsing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.preview),
                  label: const Text('Parse & Preview'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _replaceExisting,
            onChanged: _isSaving ? null : (v) => setState(() => _replaceExisting = v),
            title: const Text('Replace existing timetable for this class'),
            subtitle: const Text('Deletes existing entries for the same branch/year/semester/class before importing.'),
          ),
          const SizedBox(height: 8),
          if (hasParsed) ...[
            Text(
              'Faculty Assignment (${_assignmentKeys.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<AppUser>>(
              stream: _db.getApprovedFaculty(),
              builder: (context, snap) {
                final faculty = (snap.data ?? [])
                    .where((u) => u.pnr.trim().isNotEmpty)
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                if (snap.hasError) {
                  return Text('Failed to load faculty: ${snap.error}');
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    faculty.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (faculty.isEmpty) {
                  return const Text('No approved faculty found. Add/approve faculty first.');
                }

                return Column(
                  children: _assignmentKeys.map((key) {
                    final suggested = _suggestedFacultyNameByKey[key.id] ?? '';
                    final selected = _facultySelectionByKey[key.id];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              key.isPractical
                                  ? '${key.subjectName} (${key.batchName})'
                                  : key.subjectName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (suggested.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Suggested (from JSON): $suggested',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _isSaving
                                  ? null
                                  : () async {
                                      final picked = await _showFacultySearchDialog(
                                        faculty: faculty,
                                        current: selected,
                                      );
                                      if (!mounted || picked == null) return;
                                      setState(() {
                                        _facultySelectionByKey[key.id] = picked;
                                      });
                                    },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Assign Faculty (search)',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.search),
                                ),
                                child: Text(
                                  selected == null
                                      ? 'Tap to select'
                                      : '${selected.name} (${selected.pnr})',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Imported Timetable'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
