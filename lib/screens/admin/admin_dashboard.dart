import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartattendance/services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/user_model.dart';
import '../../models/subject_assignment.dart';
import '../../models/class_coordinator_assignment.dart';
import '../../utils/college_data.dart';
import '../../widgets/sidebar_nav_item.dart';
import 'timetable_management_screen.dart';
import '../../utils/skeleton.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  final int initialIndex;
  const AdminDashboard({super.key, this.initialIndex = 0});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const _ApproveStudentsPage(),
    const _ApproveFacultyPage(),
    const TimetableManagementScreen(
      showAddTimetable: false,
      showImportJson: true,
    ),
    const TimetableManagementScreen(
      showAddTimetable: true,
      showImportJson: false,
    ),
    const _ClassCoordinatorPage(),
  ];

  void _selectPage(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    _currentIndex = safeIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('WITClassroom'),
      ),
      body: _pages[_currentIndex],
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'android/app/src/main/res/wit.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Divider(height: 1, thickness: 1),
              ),
              const SizedBox(height: 14),
              SidebarNavItem(
                label: 'Student Approvals',
                icon: Icons.pending_actions_outlined,
                selected: _currentIndex == 0,
                onTap: () => _selectPage(0),
              ),
              SidebarNavItem(
                label: 'Faculty Approvals',
                icon: Icons.verified_user_outlined,
                selected: _currentIndex == 1,
                onTap: () => _selectPage(1),
              ),
                SidebarNavItem(
                label: 'JSON Timetable',
                icon: Icons.schedule_outlined,
                selected: _currentIndex == 2,
                onTap: () => _selectPage(2),
              ),
              SidebarNavItem(
                label: 'Mannual Timetable',
                icon: Icons.edit_calendar_outlined,
                selected: _currentIndex == 3,
                onTap: () => _selectPage(3),
              ),
              SidebarNavItem(
                label: 'Add Class Coordinator',
                icon: Icons.person_search_outlined,
                selected: _currentIndex == 4,
                onTap: () => _selectPage(4),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              SidebarNavItem(
                label: 'Logout',
                icon: Icons.logout,
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  context.read<AuthService>().logout();
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// Sub-page: Approve Students
class _ApproveStudentsPage extends StatelessWidget {
  const _ApproveStudentsPage();

  Future<bool> _confirmReject(BuildContext context, String name) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject request?'),
        content: Text('Reject $name\'s signup request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return StreamBuilder<List<AppUser>>(
      stream: db.getPendingStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonListView(itemCount: 8);
        }
        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _AdminEmptyState(
                title: 'No pending requests',
                message: 'New student approval requests will appear here.',
                icon: Icons.task_alt_rounded,
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...students.map((student) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              student.name.isNotEmpty
                                  ? student.name[0].toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PNR: ${student.pnr}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 96,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await db.approveStudent(student.pnr);
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${student.name} approved!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 96,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final ok = await _confirmReject(
                                    context,
                                    student.name,
                                  );
                                  if (!ok) return;
                                  try {
                                    await db.rejectUser(student.pnr);
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${student.name} rejected.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// Sub-page: Approve Faculty
class _ApproveFacultyPage extends StatelessWidget {
  const _ApproveFacultyPage();

  Future<bool> _confirmReject(BuildContext context, String name) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject request?'),
        content: Text('Reject $name\'s signup request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return StreamBuilder<List<AppUser>>(
      stream: db.getPendingFaculty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonListView(itemCount: 8);
        }
        final faculty = snapshot.data ?? [];
        if (faculty.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _AdminEmptyState(
                title: 'No pending requests',
                message: 'New faculty approval requests will appear here.',
                icon: Icons.task_alt_rounded,
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...faculty.map((member) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : 'F',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PNR: ${member.pnr}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 96,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await db.approveUser(member.pnr);
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${member.name} approved!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 96,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final ok =
                                      await _confirmReject(context, member.name);
                                  if (!ok) return;
                                  try {
                                    await db.rejectUser(member.pnr);
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${member.name} rejected.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ClassCoordinatorPage extends StatefulWidget {
  const _ClassCoordinatorPage();

  @override
  State<_ClassCoordinatorPage> createState() => _ClassCoordinatorPageState();
}

class _ClassCoordinatorPageState extends State<_ClassCoordinatorPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedFacultyPnr;
  String _selectedBranch = 'CSE';
  int _selectedYear = 1;
  int _selectedSemester = 1;
  String _selectedDivision = 'A';
  bool _isSaving = false;

  Future<void> _assignCoordinator(AppUser faculty) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await DatabaseService().assignClassCoordinator(
        facultyPnr: faculty.pnr,
        facultyName: faculty.name,
        branch: _selectedBranch,
        year: _selectedYear,
        semester: _selectedSemester,
        division: _selectedDivision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class coordinator assigned successfully.')),
      );
      _formKey.currentState!.reset();
      setState(() {
        _selectedBranch = 'CSE';
        _selectedYear = 1;
        _selectedSemester = 1;
        _selectedDivision = 'A';
        _selectedFacultyPnr = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAssignment(String id) async {
    try {
      await DatabaseService().deleteClassCoordinator(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinator assignment removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Class Coordinator',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Assign a faculty member to manage one class group.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      StreamBuilder<List<AppUser>>(
                        stream: DatabaseService().getApprovedFaculty(),
                        builder: (context, snapshot) {
                          final faculties = snapshot.data ?? const [];
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedFacultyPnr,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              labelText: 'Coordinator Faculty',
                            ),
                            items: faculties
                                .map((faculty) => DropdownMenuItem(
                                      value: faculty.pnr,
                                      child: Text('${faculty.name} (${faculty.pnr})'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFacultyPnr = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Select a faculty member';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBranch,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.account_tree_outlined),
                                labelText: 'Department',
                              ),
                              items: CollegeData.branches
                                  .map((branch) => DropdownMenuItem(
                                        value: branch,
                                        child: Text(branch),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedBranch = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedYear,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.calendar_month),
                                labelText: 'Year',
                              ),
                              items: CollegeData.years
                                  .map((year) => DropdownMenuItem(
                                        value: year,
                                        child: Text('$year'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedYear = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedSemester,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.school),
                                labelText: 'Semester',
                              ),
                              items: CollegeData.semesters
                                  .map((semester) => DropdownMenuItem(
                                        value: semester,
                                        child: Text('$semester'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedSemester = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedDivision,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.dashboard_outlined),
                                labelText: 'Division',
                              ),
                              items: CollegeData.divisions
                                  .map((division) => DropdownMenuItem(
                                        value: division,
                                        child: Text(division),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedDivision = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  final faculty = await DatabaseService()
                                      .getUserByPnr(_selectedFacultyPnr ?? '');
                                  if (faculty == null) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please select a faculty member.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  await _assignCoordinator(faculty);
                                },
                          child: Text(_isSaving ? 'Saving...' : 'Assign Coordinator'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Current Coordinator Assignments',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ClassCoordinatorAssignment>>(
          stream: DatabaseService().watchClassCoordinators(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonListView(itemCount: 4);
            }
            final assignments = snapshot.data ?? [];
            if (assignments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No class coordinators assigned yet.'),
                ),
              );
            }
            return Column(
              children: assignments.map((assignment) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      title: Text(
                        '${assignment.facultyName} (${assignment.facultyPnr})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${assignment.branch} • Year ${assignment.year} • Sem ${assignment.semester} • Div ${assignment.division}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete assignment?'),
                              content: const Text(
                                'Remove this class coordinator assignment?',
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
                          if (confirm == true) {
                            await _deleteAssignment(assignment.id);
                          }
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// Sub-page: Add Faculty
class _AddFacultyPage extends StatefulWidget {
  const _AddFacultyPage();
  @override
  State<_AddFacultyPage> createState() => _AddFacultyPageState();
}
class _AddFacultyPageState extends State<_AddFacultyPage> {
  final _formKey = GlobalKey<FormState>();
  final _pnrController = TextEditingController();
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _addFaculty() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newFaculty = AppUser(
          pnr: _pnrController.text.trim(),
          name: _nameController.text.trim(),
          role: 'faculty',
          isApproved: true,
          subject: _subjectController.text.trim(),
        );
        await DatabaseService().createFaculty(newFaculty, _passwordController.text);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faculty Created successfully.')));
          _formKey.currentState!.reset();
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.person_add_alt_1, size: 48, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Register New Faculty',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a secure account for a new faculty member.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Icon(Icons.person_add_alt_1, size: 30, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Register New Faculty',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a secure account for a new faculty member.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _pnrController,
              label: 'Faculty PNR / Username',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Faculty Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _subjectController,
              label: 'Assigned Subject',
              icon: Icons.book_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Set Password',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _addFaculty,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Create Faculty Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      textInputAction:
          isPassword ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (!isPassword) {
          FocusScope.of(context).nextFocus();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }
}

// Sub-page: Assign Subjects
class _AssignSubjectPage extends StatefulWidget {
  const _AssignSubjectPage();

  @override
  State<_AssignSubjectPage> createState() => _AssignSubjectPageState();
}

class _AssignSubjectPageState extends State<_AssignSubjectPage> {
  final _db = DatabaseService();
  final _branchController = TextEditingController();
  final _divisionController = TextEditingController();
  final _yearController = TextEditingController();
  final _semesterController = TextEditingController();
  final _subjectController = TextEditingController();
  String? _selectedFacultyPnr;
  String? _selectedFacultyName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _yearController.addListener(_handleYearChange);
  }

  void _handleYearChange() {
    final year = int.tryParse(_yearController.text.trim());
    final divisions = CollegeData.divisionsForYear(year);
    final current = _divisionController.text.trim().toUpperCase();
    if (current.isNotEmpty && !divisions.contains(current)) {
      setState(() => _divisionController.text = '');
    }
  }

  @override
  void dispose() {
    _yearController.removeListener(_handleYearChange);
    _branchController.dispose();
    _divisionController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    final branch = _branchController.text.trim().toUpperCase();
    final division = _divisionController.text.trim().toUpperCase();
    final year = int.tryParse(_yearController.text.trim());
    final semester = int.tryParse(_semesterController.text.trim());
    final subject = _subjectController.text.trim();
    final facultyPnr = _selectedFacultyPnr;
    final facultyName = _selectedFacultyName;

    if (branch.isEmpty ||
        division.isEmpty ||
        year == null ||
        semester == null ||
        subject.isEmpty ||
        facultyPnr == null ||
        facultyName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _db.assignSubjectToFaculty(
        branch: branch,
        division: division,
        year: year,
        semesterNumber: semester,
        facultyPnr: facultyPnr,
        facultyName: facultyName,
        subject: subject,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject assigned successfully.')),
      );
      _subjectController.clear();
      setState(() => _isSaving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign subject: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAssignment(String id) async {
    try {
      await _db.deleteSubjectAssignment(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject assignment removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = int.tryParse(_yearController.text.trim());
    final divisions = CollegeData.divisionsForYear(year);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assign Manual Subjects',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose dept/branch, year, semester and faculty, then assign a subject for attendance tracking.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          _buildDropdownField(
            controller: _branchController,
            label: 'Dept / Branch',
            items: CollegeData.branches,
          ),
          _buildDropdownField(
            controller: _yearController,
            label: 'Year',
            items: CollegeData.years.map((e) => e.toString()).toList(),
          ),
          _buildDropdownField(
            controller: _divisionController,
            label: 'Division',
            items: divisions,
          ),
          _buildDropdownField(
            controller: _semesterController,
            label: 'Semester',
            items: CollegeData.semesters.map((e) => e.toString()).toList(),
          ),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<AppUser>>(
            stream: _db.getApprovedFaculty(),
            builder: (context, snapshot) {
              final faculty = snapshot.data ?? const <AppUser>[];
              return DropdownButtonFormField<String>(
                initialValue: _selectedFacultyPnr,
                decoration: InputDecoration(
                  labelText: 'Faculty',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: faculty.map((member) {
                  return DropdownMenuItem(
                    value: member.pnr,
                    child: Text('${member.name} (${member.pnr})'),
                  );
                }).toList(),
                onChanged: (value) {
                  final selectedFaculty = faculty.firstWhere(
                    (member) => member.pnr == value,
                    orElse: () => AppUser(pnr: '', name: '', role: 'faculty'),
                  );
                  setState(() {
                    _selectedFacultyPnr = value;
                    _selectedFacultyName = selectedFaculty.name;
                  });
                },
                hint: snapshot.connectionState == ConnectionState.waiting
                    ? const Text('Loading faculty...')
                    : const Text('Select faculty'),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAssignment,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isSaving ? 'Saving…' : 'Assign Subject'),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Assigned Subjects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SubjectAssignment>>(
            stream: _db.watchSubjectAssignments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final assignments = snapshot.data ?? const <SubjectAssignment>[];
              if (assignments.isEmpty) {
                return const Text('No subjects assigned yet.');
              }

              return SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: assignments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        title: Text(assignment.subject),
                        subtitle: Text(
                          '${assignment.branch} · Year ${assignment.year} · Sem ${assignment.semesterNumber}\nAssigned to ${assignment.facultyName}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteAssignment(assignment.id),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: items
            .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value),
                ))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            controller.text = value;
          });
        },
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _AdminEmptyState({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
