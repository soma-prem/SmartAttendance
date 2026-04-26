import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/db_service.dart';
import '../../utils/college_data.dart';

enum _FacultyNotifType { lectureCancelled, general }

class FacultySendNotificationScreen extends StatefulWidget {
  final String facultyPnr;
  const FacultySendNotificationScreen({super.key, required this.facultyPnr});

  @override
  State<FacultySendNotificationScreen> createState() =>
      _FacultySendNotificationScreenState();
}

class _FacultySendNotificationScreenState
    extends State<FacultySendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _branch;
  int? _year;
  String? _division;
  int? _semester;
  String? _batch;

  _FacultyNotifType _type = _FacultyNotifType.lectureCancelled;

  DateTime _date = DateTime.now();
  String _startTime = '';
  String _endTime = '';
  String _subject = '';

  String _title = '';
  String _body = '';

  bool _sending = false;
  int? _recipientCount;

  String get _className {
    final b = _branch?.trim();
    final d = _division?.trim();
    if (b == null || b.isEmpty || d == null || d.isEmpty) return '';
    return '$b-$d';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date,
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  String _buildLectureCancelledTitle() {
    final subject = _subject.trim().isEmpty ? 'Lecture' : _subject.trim();
    return '$subject Cancelled';
  }

  String _buildLectureCancelledBody() {
    final subject = _subject.trim().isEmpty ? 'Lecture' : _subject.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final timePart = [
      _startTime.trim(),
      _endTime.trim(),
    ].where((t) => t.isNotEmpty).toList();
    final timeStr = timePart.isEmpty ? '' : ' (${timePart.join(' - ')})';
    return '$subject for $_className is cancelled on $dateStr$timeStr.';
  }

  Future<int> _previewRecipients() async {
    final className = _className;
    if (className.isEmpty) return 0;

    final students = await DatabaseService().getStudentsByClass(
      className,
      branch: _branch,
      year: _year?.toString(),
      semester: _semester,
      batch: _batch?.trim(),
    );
    return students.length;
  }

  Future<void> _refreshRecipientCount() async {
    setState(() => _recipientCount = null);
    try {
      final count = await _previewRecipients();
      if (!mounted) return;
      setState(() => _recipientCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _recipientCount = 0);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    _formKey.currentState?.save();

    final className = _className;
    if (className.isEmpty) return;

    final title = _type == _FacultyNotifType.lectureCancelled
        ? (_title.trim().isEmpty ? _buildLectureCancelledTitle() : _title.trim())
        : _title.trim();

    final body = _type == _FacultyNotifType.lectureCancelled
        ? (_body.trim().isEmpty ? _buildLectureCancelledBody() : _body.trim())
        : _body.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and message.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final count = await DatabaseService().sendNotificationToStudentsByFilter(
        title: title,
        body: body,
        className: className,
        branch: _branch,
        year: _year?.toString(),
        semester: _semester,
        batch: _batch?.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0 ? 'No matching students found.' : 'Sent to $count students.',
          ),
        ),
      );
      if (count > 0) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = _year;
    final divisions = CollegeData.divisionsForYear(year);

    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _branch,
                    decoration: const InputDecoration(
                      labelText: 'Dept / Branch',
                      border: OutlineInputBorder(),
                    ),
                    items: CollegeData.branches
                        .map(
                          (b) => DropdownMenuItem(value: b, child: Text(b)),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _branch = v;
                      });
                      _refreshRecipientCount();
                    },
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: CollegeData.years
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _year = v;
                        _division = null;
                      });
                      _refreshRecipientCount();
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _division,
                    decoration: const InputDecoration(
                      labelText: 'Class / Division',
                      border: OutlineInputBorder(),
                    ),
                    items: divisions
                        .map(
                          (d) => DropdownMenuItem(value: d, child: Text(d)),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _division = v);
                      _refreshRecipientCount();
                    },
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _semester,
                    decoration: const InputDecoration(
                      labelText: 'Semester (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Any'),
                      ),
                      ...CollegeData.semesters.map(
                        (s) => DropdownMenuItem(value: s, child: Text('$s')),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _semester = v);
                      _refreshRecipientCount();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _batch,
              decoration: const InputDecoration(
                labelText: 'Batch (optional)',
                hintText: 'e.g. A1',
                border: OutlineInputBorder(),
              ),
              onSaved: (v) => _batch = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              onSaved: (v) => _subject = (v ?? ''),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    RadioGroup<_FacultyNotifType>(
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v!),
                      child: Column(
                        children: [
                          RadioListTile<_FacultyNotifType>(
                            value: _FacultyNotifType.lectureCancelled,
                            title: const Text('Lecture cancelled'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<_FacultyNotifType>(
                            value: _FacultyNotifType.general,
                            title: const Text('General message'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_type == _FacultyNotifType.lectureCancelled) ...[
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _startTime,
                      decoration: const InputDecoration(
                        labelText: 'Start time (optional)',
                        hintText: '10:15 AM',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _startTime = v ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _endTime,
                      decoration: const InputDecoration(
                        labelText: 'End time (optional)',
                        hintText: '11:15 AM',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _endTime = v ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              initialValue: _title,
              decoration: InputDecoration(
                labelText: 'Title${_type == _FacultyNotifType.lectureCancelled ? ' (optional)' : ''}',
                border: const OutlineInputBorder(),
              ),
              onSaved: (v) => _title = v ?? '',
              validator: (v) {
                if (_type == _FacultyNotifType.general &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _body,
              decoration: InputDecoration(
                labelText: 'Message${_type == _FacultyNotifType.lectureCancelled ? ' (optional)' : ''}',
                border: const OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 6,
              onSaved: (v) => _body = v ?? '',
              validator: (v) {
                if (_type == _FacultyNotifType.general &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _className.isEmpty
                        ? 'Select dept / branch/year/class.'
                        : _recipientCount == null
                            ? 'Recipients: (tap Refresh)'
                            : 'Recipients: $_recipientCount',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                TextButton.icon(
                  onPressed: _className.isEmpty ? null : _refreshRecipientCount,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}
