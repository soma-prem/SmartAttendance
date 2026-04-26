import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/timetable_entry.dart';
import '../../services/db_service.dart';
import '../../utils/college_data.dart';
import 'timetable_json_import_tab.dart';
import '../timetable_table_view.dart';

class TimetableManagementScreen extends StatefulWidget {
  final bool showAddTimetable;
  final bool showImportJson;

  const TimetableManagementScreen({
    super.key,
    this.showAddTimetable = true,
    this.showImportJson = true,
  });

  @override
  State<TimetableManagementScreen> createState() =>
      _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends State<TimetableManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filter Controllers
  final _branchController = TextEditingController();
  final _yearController = TextEditingController();
  final _semesterController = TextEditingController();
  final _classController = TextEditingController();
  final _semStartController = TextEditingController();
  final _semEndController = TextEditingController();
  DateTime? _semesterStartDate;
  DateTime? _semesterEndDate;

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
    final length = 1 + (widget.showAddTimetable ? 1 : 0) +
        (widget.showImportJson ? 1 : 0);
    _tabController = TabController(length: length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _branchController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    _classController.dispose();
    _semStartController.dispose();
    _semEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).primaryColor,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              if (widget.showAddTimetable) const Tab(text: 'Add Timetable'),
              if (widget.showImportJson) const Tab(text: 'Import JSON'),
              const Tab(text: 'View/Edit'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              if (widget.showAddTimetable) _buildAddTimetableTab(),
              if (widget.showImportJson) const TimetableJsonImportTab(),
              _buildViewEditTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddTimetableTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Semester Timetable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildBranchDropdown(_branchController),
          _buildYearDropdown(_yearController),
          _buildSemesterDropdown(_semesterController),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  controller: _semStartController,
                  label: 'Semester Start Date',
                  onPicked: (date) => setState(() => _semesterStartDate = date),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateField(
                  controller: _semEndController,
                  label: 'Semester End Date',
                  onPicked: (date) => setState(() => _semesterEndDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDayScheduleBuilder(),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown(TextEditingController controller) {
    final current = controller.text.trim().toUpperCase();
    final value = CollegeData.branches.contains(current) ? current : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Branch',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: CollegeData.branches
            .map(
              (branch) => DropdownMenuItem(value: branch, child: Text(branch)),
            )
            .toList(),
        onChanged: (val) {
          setState(() {
            controller.text = val ?? '';
          });
        },
      ),
    );
  }

  Widget _buildYearDropdown(TextEditingController controller) {
    final parsed = int.tryParse(controller.text.trim());
    final value = CollegeData.years.contains(parsed) ? parsed : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Year',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: CollegeData.years
            .map((year) => DropdownMenuItem(value: year, child: Text('$year')))
            .toList(),
        onChanged: (val) {
          setState(() {
            controller.text = val?.toString() ?? '';
          });
        },
      ),
    );
  }

  Widget _buildSemesterDropdown(TextEditingController controller) {
    final parsed = int.tryParse(controller.text.trim());
    final value = CollegeData.semesters.contains(parsed) ? parsed : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Semester',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: CollegeData.semesters
            .map((sem) => DropdownMenuItem(value: sem, child: Text('$sem')))
            .toList(),
        onChanged: (val) {
          setState(() {
            controller.text = val?.toString() ?? '';
          });
        },
      ),
    );
  }

  Widget _buildDayScheduleBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Classes for Each Day (6-Day Schedule)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        ..._days.map((day) => _buildDayPanel(day)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _showTimetableSummary(),
            child: const Text('Review & Save Timetable'),
          ),
        ),
      ],
    );
  }

  Widget _buildDayPanel(String day) {
    return ExpansionTile(
      title: Text(
        day,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _DayScheduleForm(
            day: day,
            branchController: _branchController,
            yearController: _yearController,
            semesterController: _semesterController,
            semesterStart: _semesterStartDate,
            semesterEnd: _semesterEndDate,
            onSave: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        keyboardType: inputType,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<DateTime> onPicked,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Select date',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final now = DateTime.now();
          final initial = controller.text.isNotEmpty
              ? DateFormat('dd-MMM-yyyy').parse(controller.text)
              : now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 5),
          );
          if (picked != null) {
            controller.text = DateFormat('dd-MMM-yyyy').format(picked);
            onPicked(picked);
          }
        },
      ),
    );
  }

  Widget _buildViewEditTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildBranchDropdown(_branchController)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildYearDropdown(_yearController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildSemesterDropdown(_semesterController)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      _classController,
                      'Class (Optional)',
                      '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_branchController.text.isEmpty ||
                        _yearController.text.isEmpty ||
                        _semesterController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all filters'),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TimetableTableView(
                          branch: _branchController.text.trim(),
                          year: int.parse(_yearController.text.trim()),
                          semester: int.parse(_semesterController.text.trim()),
                          isAdmin: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('View/Edit in Table Format'),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('Use the filter above to view the tabular timetable'),
          ),
        ),
      ],
    );
  }

  Future<void> _showTimetableSummary() async {
    _tabController.animateTo(1);
  }
}

// Sub-widget for adding classes for a specific day
class _DayScheduleForm extends StatefulWidget {
  final String day;
  final TextEditingController branchController;
  final TextEditingController yearController;
  final TextEditingController semesterController;
  final DateTime? semesterStart;
  final DateTime? semesterEnd;
  final VoidCallback onSave;

  const _DayScheduleForm({
    required this.day,
    required this.branchController,
    required this.yearController,
    required this.semesterController,
    required this.semesterStart,
    required this.semesterEnd,
    required this.onSave,
  });

  @override
  State<_DayScheduleForm> createState() => _DayScheduleFormState();
}

class _DayScheduleFormState extends State<_DayScheduleForm> {
  final List<Map<String, TextEditingController>> _classes = [];
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _addClassSlot();
  }

  void _addClassSlot() {
    setState(() {
      _classes.add({
        'subject': TextEditingController(),
        'startTime': TextEditingController(),
        'endTime': TextEditingController(),
        'facultyPnr': TextEditingController(),
        'facultyName': TextEditingController(),
        'className': TextEditingController(),
        'batchName': TextEditingController(),
      });
    });
  }

  void _addPracticalSlot() {
    final startTime = TextEditingController();
    final endTime = TextEditingController();
    final className = TextEditingController();

    setState(() {
      for (var batch in ['B1', 'B2', 'B3']) {
        _classes.add({
          'subject': TextEditingController(),
          'startTime': startTime, // Shared controller for time
          'endTime': endTime, // Shared controller for time
          'facultyPnr': TextEditingController(),
          'facultyName': TextEditingController(),
          'className': className, // Shared controller for class
          'batchName': TextEditingController(text: batch),
        });
      }
    });
  }

  void _removeClassSlot(int index) {
    setState(() {
      for (var controller in _classes[index].values) {
        controller.dispose();
      }
      _classes.removeAt(index);
    });
  }

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty) {
      return null;
    }

    try {
      final parsed = DateFormat('hh:mm a').parse(value);
      return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay time) {
    final dateTime = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dateTime);
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _parseTime(controller.text) ?? TimeOfDay.now(),
    );

    if (pickedTime == null) {
      return;
    }

    controller.text = _formatTime(pickedTime);
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectTime(controller),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select time',
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
      ),
    );
  }

  Future<void> _saveClasses() async {
    final branch = widget.branchController.text.trim();
    final year = int.tryParse(widget.yearController.text.trim());
    final semester = int.tryParse(widget.semesterController.text.trim());
    final start = widget.semesterStart;
    final end = widget.semesterEnd;

    if (branch.isEmpty || year == null || semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter branch, year, and semester first'),
        ),
      );
      return;
    }

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick semester start and end dates'),
        ),
      );
      return;
    }

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semester end date cannot be before start date'),
        ),
      );
      return;
    }

    final entries = <TimetableEntry>[];
    int index = 0;

    for (var classData in _classes) {
      if (classData['subject']!.text.isEmpty ||
          classData['startTime']!.text.isEmpty ||
          classData['endTime']!.text.isEmpty ||
          classData['facultyPnr']!.text.isEmpty ||
          classData['className']!.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all fields for each class'),
          ),
        );
        return;
      }

      final batchName = classData['batchName']!.text.trim();

      entries.add(
        TimetableEntry(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              index.toString(),
          day: widget.day,
          startTime: classData['startTime']!.text,
          endTime: classData['endTime']!.text,
          subject: classData['subject']!.text,
          facultyPnr: classData['facultyPnr']!.text,
          facultyName: classData['facultyName']!.text,
          className: classData['className']!.text,
          batchName: batchName.isEmpty ? null : batchName,
          semesterNumber: semester,
          year: year,
          branch: branch,
          createdAt: DateTime.now(),
        ),
      );
      index++;
    }

    try {
      await _db.setSemesterWindow(branch, year, semester, start, end);
      await _db.addBulkTimetableEntries(entries);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entries.length} class(es) added for ${widget.day}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSave();
        // Clear the form
        for (var classData in _classes) {
          for (var controller in classData.values) {
            controller.clear();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ..._classes.asMap().entries.map((entry) {
          final index = entry.key;
          final controllers = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Class ${index + 1}'),
                        if (_classes.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeClassSlot(index),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controllers['subject'],
                            decoration: const InputDecoration(
                              labelText: 'Subject Name',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controllers['batchName'],
                            decoration: const InputDecoration(
                              labelText: 'Batch (Optional)',
                              hintText: 'e.g., B1',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeField(
                            controller: controllers['startTime']!,
                            label: 'Start Time',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimeField(
                            controller: controllers['endTime']!,
                            label: 'End Time',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controllers['className'],
                      decoration: const InputDecoration(
                        labelText: 'Class Name/Section',
                        hintText: 'e.g., CSE-A',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controllers['facultyPnr'],
                      decoration: const InputDecoration(
                        labelText: 'Faculty PNR',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controllers['facultyName'],
                      decoration: const InputDecoration(
                        labelText: 'Faculty Name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addClassSlot,
                icon: const Icon(Icons.add),
                label: const Text('Add Class'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addPracticalSlot,
                icon: const Icon(Icons.group_work),
                label: const Text('Add Practical'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveClasses,
            icon: const Icon(Icons.save),
            label: Text('Save Classes for ${widget.day}'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var classData in _classes) {
      for (var controller in classData.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }
}
