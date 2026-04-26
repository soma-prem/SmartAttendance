import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/timetable_entry.dart';
import '../../models/attendance_record.dart';
import '../../models/class_coordinator_assignment.dart';
import '../../models/dispute_model.dart';
import '../../models/user_model.dart';
import '../../services/attendance_pdf_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../models/notification_model.dart';
import '../notifications_screen.dart';
import '../classroom/classroom_gate_screen.dart';
import '../../utils/skeleton.dart';
import 'attendance_history_screen.dart';
import 'faculty_send_notification_screen.dart';
import 'faculty_ise_screen.dart';
import '../../widgets/sidebar_profile_header.dart';
import '../../widgets/sidebar_nav_item.dart';

class FacultyDashboard extends StatefulWidget {
  final int initialIndex;
  const FacultyDashboard({super.key, this.initialIndex = 0});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _currentIndex = 0;
  Timer? _reminderTimer;
  final Set<String> _remindedLectures = {};
  String? _cachedPnr;
  Stream<List<AppNotification>>? _notificationStream;
  String? _profilePhotoBase64;
  bool _isSavingProfilePhoto = false;
  String? _sidebarBgBase64;
  bool _isSavingSidebarBg = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().currentUser;
    if (user != null && user.pnr != _cachedPnr) {
      _cachedPnr = user.pnr;
      _notificationStream = DatabaseService().getNotifications(user.pnr);
      _loadProfilePhotoBase64(user.pnr);
      _loadSidebarBackground(user.pnr);
    }
  }

  Future<void> _loadProfilePhotoBase64(String pnr) async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('faculty_profile_photo_b64_$pnr');
    if (!mounted) return;
    setState(() => _profilePhotoBase64 = b64);
  }

  Future<void> _loadSidebarBackground(String pnr) async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('faculty_sidebar_bg_b64_$pnr');
    if (!mounted) return;
    setState(() => _sidebarBgBase64 = b64);
  }

  Future<void> _changeProfilePhoto(String pnr) async {
    if (_isSavingProfilePhoto) return;

    setState(() => _isSavingProfilePhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('faculty_profile_photo_b64_$pnr', b64);

      if (!mounted) return;
      setState(() => _profilePhotoBase64 = b64);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfilePhoto = false);
      }
    }
  }

  Future<void> _changeSidebarBackground(String pnr) async {
    if (_isSavingSidebarBg) return;

    setState(() => _isSavingSidebarBg = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 512,
      );

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('faculty_sidebar_bg_b64_$pnr', b64);

      if (!mounted) return;
      setState(() => _sidebarBgBase64 = b64);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update background image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSidebarBg = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _startReminderSystem();
  }

  void _startReminderSystem() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkUpcomingLectures();
    });
  }

  Future<void> _checkUpcomingLectures() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      final entries = await DatabaseService()
          .getTimetableForFaculty(user.pnr)
          .first;
      final now = DateTime.now();
      final dayOrder = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      final currentDay = dayOrder[now.weekday - 1];

      for (var entry in entries) {
        if (entry.day.toLowerCase() != currentDay) continue;

        final startTimeParsed = DateFormat('hh:mm a').parse(entry.startTime);
        final lectureStartTime = DateTime(
          now.year,
          now.month,
          now.day,
          startTimeParsed.hour,
          startTimeParsed.minute,
        );

        final difference = lectureStartTime.difference(now).inMinutes;

        if (difference > 0 &&
            difference <= 10 &&
            !_remindedLectures.contains(entry.id)) {
          _remindedLectures.add(entry.id);
          DatabaseService().sendNotification(
            user.pnr,
            'Lecture Reminder',
            'Your ${entry.subject} class for ${entry.className} starts in $difference minutes.',
          );
        }
      }
    } catch (e) {
      debugPrint('Faculty reminder system error: $e');
    }
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final List<Widget> pages = [
      _FacultyTimetablePage(facultyPnr: user.pnr, user: user),
      _MarkAttendancePage(
        facultyPnr: user.pnr,
        facultyName: user.name,
        subject: user.subject ?? 'Unknown',
      ),
      AttendanceHistoryScreen(facultyPnr: user.pnr),
      _ResolveDisputesPage(
        facultySubject: user.subject ?? '',
        facultyPnr: user.pnr,
      ),
      _ClassCoordinatorPage(facultyPnr: user.pnr),
    ];
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SidebarProfileHeader(
                  pnr: user.pnr,
                  displayName: user.name,
                  subtitle: user.subject?.trim().isNotEmpty == true
                      ? user.subject
                      : 'Faculty',
                  profilePhotoBase64: _profilePhotoBase64,
                  backgroundPhotoBase64: _sidebarBgBase64,
                  isSavingPhoto: _isSavingProfilePhoto,
                  isSavingBackground: _isSavingSidebarBg,
                  onEditPhoto: _isSavingProfilePhoto
                      ? null
                      : () => _changeProfilePhoto(user.pnr),
                  onEditBackground: _isSavingSidebarBg
                      ? null
                      : () => _changeSidebarBackground(user.pnr),
                  showEditButtons: true,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<ClassCoordinatorAssignment>>(
                stream: DatabaseService().watchCoordinatorAssignmentsForFaculty(
                  user.pnr,
                ),
                builder: (context, snapshot) {
                  final hasCoordinator = snapshot.data?.isNotEmpty == true;
                  if (!hasCoordinator && _currentIndex == 4) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _currentIndex = 0;
                        });
                      }
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SidebarNavItem(
                        label: 'Schedule',
                        icon: Icons.schedule_outlined,
                        selected: _currentIndex == 0,
                        onTap: () {
                          setState(() => _currentIndex = 0);
                          Navigator.pop(context);
                        },
                      ),
                      SidebarNavItem(
                        label: 'Attendance',
                        icon: Icons.fact_check_outlined,
                        selected: _currentIndex == 1,
                        onTap: () {
                          setState(() => _currentIndex = 1);
                          Navigator.pop(context);
                        },
                      ),
                      SidebarNavItem(
                        label: 'Attendance History',
                        icon: Icons.history,
                        selected: _currentIndex == 2,
                        onTap: () {
                          setState(() => _currentIndex = 2);
                          Navigator.pop(context);
                        },
                      ),
                      SidebarNavItem(
                        label: 'ISE',
                        icon: Icons.grading_outlined,
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FacultyIseScreen(
                                facultyPnr: user.pnr,
                                facultyName: user.name,
                              ),
                            ),
                            (route) => route.settings.name == '/faculty_dashboard' || route.isFirst,
                          );
                        },
                      ),
                      SidebarNavItem(
                        label: 'Disputes',
                        icon: Icons.report_problem_outlined,
                        selected: _currentIndex == 3,
                        onTap: () {
                          setState(() => _currentIndex = 3);
                          Navigator.pop(context);
                        },
                      ),
                      SidebarNavItem(
                        label: 'Go To Classroom',
                        icon: Icons.meeting_room_outlined,
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ClassroomGateScreen(),
                            ),
                            (route) => route.settings.name == '/faculty_dashboard' || route.isFirst,
                          );
                        },
                      ),
                      SidebarNavItem(
                        label: 'Send Notification',
                        icon: Icons.notifications_outlined,
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FacultySendNotificationScreen(
                                facultyPnr: user.pnr,
                              ),
                            ),
                            (route) => route.settings.name == '/faculty_dashboard' || route.isFirst,
                          );
                        },
                      ),
                      if (hasCoordinator)
                        SidebarNavItem(
                          label: 'My Class',
                          icon: Icons.class_outlined,
                          selected: _currentIndex == 4,
                          onTap: () {
                            setState(() => _currentIndex = 4);
                            Navigator.pop(context);
                          },
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('WITClassroom'),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notificationStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.hasData
                  ? snapshot.data!.where((n) => !n.isRead).length
                  : 0;

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const IconButton(
                  icon: Icon(Icons.notifications_none),
                  onPressed: null,
                );
              }

              return IconButton(
                icon: Badge(
                  label: unreadCount > 0 ? Text('$unreadCount') : null,
                  isLabelVisible: unreadCount > 0,
                  backgroundColor: Colors.redAccent,
                  child: Icon(
                    unreadCount > 0
                        ? Icons.notifications_active
                        : Icons.notifications,
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationScreen(pnr: user.pnr),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: pages[safeIndex],
    );
  }
}

// Sub-page: Timetable
class _FacultyTimetablePage extends StatelessWidget {
  final String facultyPnr;
  final AppUser user;
  const _FacultyTimetablePage({required this.facultyPnr, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<TimetableEntry>>(
            stream: DatabaseService().getTimetableForFaculty(facultyPnr),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonListView(itemCount: 8);
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No schedule found.'));
              }

              final schedule = snapshot.data!;

              // Group by day
              final groupedByDay = <String, List<TimetableEntry>>{};
              for (var entry in schedule) {
                // Standardize day format (capitalize first letter)
                final dayKey = entry.day.isNotEmpty
                    ? entry.day[0].toUpperCase() +
                          entry.day.substring(1).toLowerCase()
                    : 'Unknown';
                groupedByDay.putIfAbsent(dayKey, () => []);
                groupedByDay[dayKey]!.add(entry);
              }

              // Sort groups by day order (including Sunday)
              final dayOrder = [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ];
              final sortedDays = groupedByDay.keys.toList()
                ..sort(
                  (a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)),
                );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Weekly Timetable',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedDays.length,
                      itemBuilder: (context, index) {
                        final day = sortedDays[index];
                        final entries = groupedByDay[day]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    day,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${entries.length})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...entries.map((entry) {
                              final isPractical = entry.batchName != null;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey[100]!),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        decoration: BoxDecoration(
                                          color: isPractical
                                              ? Colors.orange
                                              : Theme.of(context).primaryColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    entry.startTime.split(
                                                      ' ',
                                                    )[0],
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    entry.startTime
                                                                .split(' ')
                                                                .length >
                                                            1
                                                        ? entry.startTime.split(
                                                            ' ',
                                                          )[1]
                                                        : '',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              VerticalDivider(
                                                color: Colors.grey[200],
                                                thickness: 1,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      entry.subject,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 17,
                                                        letterSpacing: -0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 6,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                Icons.class_,
                                                                size: 12,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                entry.className,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .blue,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (isPractical)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .orange
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Icon(
                                                                  Icons.group,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .orange,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  'Batch ${entry.batchName}',
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .orange,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Ends at',
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    entry.endTime,
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClassCoordinatorPage extends StatefulWidget {
  final String facultyPnr;
  const _ClassCoordinatorPage({required this.facultyPnr});

  @override
  State<_ClassCoordinatorPage> createState() => _ClassCoordinatorPageState();
}

class _ClassCoordinatorPageState extends State<_ClassCoordinatorPage> {
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _error;
  ClassCoordinatorAssignment? _assignment;
  List<AppUser> _students = [];
  List<AttendanceRecord> _records = [];
  final Set<String> _selectedWeekKeys = {};

  @override
  void initState() {
    super.initState();
    _loadClassCoordinatorData();
  }

  Future<void> _loadClassCoordinatorData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _assignment = null;
      _students = [];
      _records = [];
      _selectedWeekKeys.clear();
    });

    try {
      final assignments = await DatabaseService()
          .getCoordinatorAssignmentsForFaculty(widget.facultyPnr);
      if (assignments.isEmpty) {
        setState(() {
          _assignment = null;
          _isLoading = false;
        });
        return;
      }

      final assignment = assignments.first;
      final className = '${assignment.branch}-${assignment.division}';
      final students = await DatabaseService().getStudentsByClass(
        className,
        semester: assignment.semester,
        branch: assignment.branch,
        year: assignment.year.toString(),
      );
      final records = await DatabaseService().getAttendanceRecordsForClass(
        branch: assignment.branch,
        year: assignment.year,
        semesterNumber: assignment.semester,
        className: className,
      );

      setState(() {
        _assignment = assignment;
        _students = students;
        _records = records;
        _selectedWeekKeys.addAll(_extractWeeks(records).map(_weekKey));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  DateTime _weekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  String _weekKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(_weekStart(date));

  String _weekLabel(DateTime date) {
    final start = _weekStart(date);
    final end = start.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
  }

  List<DateTime> _extractWeeks(List<AttendanceRecord> records) {
    final weeks = records.map((r) => _weekStart(r.date)).toSet().toList();
    weeks.sort((a, b) => b.compareTo(a));
    return weeks;
  }

  Future<void> _openDownloadDialog() async {
    if (_records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No attendance records available for download.'),
          ),
        );
      }
      return;
    }

    final availableWeeks = _extractWeeks(_records);
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
                    const Text(
                      'Select one or more weeks to include in the PDF report.',
                    ),
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
                          await _downloadSelectedWeeks(selectedKeys);
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

  Future<void> _downloadSelectedWeeks(Set<String> selectedWeekKeys) async {
    final selectedRecords = _records
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
      final weekStarts =
          selectedRecords.map((r) => _weekStart(r.date)).toSet().toList()
            ..sort();
      final periodLabel = weekStarts.length == 1
          ? _weekLabel(weekStarts.first)
          : '${_weekLabel(weekStarts.last)} to ${_weekLabel(weekStarts.first)}';

      await AttendancePdfService.generateAndDownloadClassCoordinatorReport(
        facultyPnr: widget.facultyPnr,
        facultyName: _assignment?.facultyName ?? widget.facultyPnr,
        title: 'Class Coordinator Attendance Report',
        periodLabel: periodLabel,
        records: selectedRecords,
        students: _students,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _launchDialer(String number) async {
    final uri = Uri(scheme: 'tel', path: number.trim());
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to launch dialer.')),
        );
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch dialer.')),
      );
    }
  }

  Future<void> _launchSms(String number) async {
    final uri = Uri(scheme: 'sms', path: number.trim());
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to launch messaging app.')),
        );
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch messaging app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonListView(itemCount: 6),
      );
    }

    if (_error != null) {
      return Center(
        child: Text('Error loading coordinator assignment: $_error'),
      );
    }

    if (_assignment == null) {
      return const Center(
        child: Text('No class coordinator assignment found.'),
      );
    }

    final weeks = _extractWeeks(_records);
    final sortedStudents = List<AppUser>.from(_students);
    sortedStudents.sort((a, b) {
      final aRoll = int.tryParse(a.rollNo?.trim() ?? '');
      final bRoll = int.tryParse(b.rollNo?.trim() ?? '');
      if (aRoll != null && bRoll != null) return aRoll.compareTo(bRoll);
      if (aRoll != null) return -1;
      if (bRoll != null) return 1;
      return (a.rollNo ?? '').compareTo(b.rollNo ?? '');
    });

    return DefaultTabController(
      length: 1,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey[700],
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Overview'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCoordinatorOverview(weeks, sortedStudents),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorOverview(List<DateTime> weeks, List<AppUser> sortedStudents) {
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
                  'My Class',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_assignment!.branch} • Year ${_assignment!.year} • Sem ${_assignment!.semester} • Div ${_assignment!.division}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Chip(label: Text('Coordinator: ${_assignment!.facultyName}')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _records.isEmpty || _isDownloading
                    ? null
                    : _openDownloadDialog,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  _isDownloading ? 'Preparing...' : 'Download Attendance',
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (weeks.isNotEmpty) ...[
          const Text('Selected Weeks'),
          const SizedBox(height: 10),
          Wrap(
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
          ),
          const SizedBox(height: 20),
        ],
        if (_students.isEmpty)
          const Center(child: Text('No students found for this class.'))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Roll No')),
                DataColumn(label: Text('PNR')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Mobile')),
                DataColumn(label: Text('Actions')),
              ],
              rows: sortedStudents.map((student) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        student.rollNo?.trim().isEmpty == true
                            ? '-'
                            : student.rollNo ?? '-',
                      ),
                    ),
                    DataCell(Text(student.pnr)),
                    DataCell(Text(student.name)),
                    DataCell(
                      Text(
                        student.phone?.trim().isEmpty == true
                            ? '-'
                            : student.phone!.trim(),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Call',
                            icon: const Icon(Icons.call),
                            onPressed: student.phone?.trim().isEmpty == true
                                ? null
                                : () => _launchDialer(student.phone!.trim()),
                          ),
                          IconButton(
                            tooltip: 'Message',
                            icon: const Icon(Icons.message),
                            onPressed: student.phone?.trim().isEmpty == true
                                ? null
                                : () => _launchSms(student.phone!.trim()),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

}

// Sub-page: Mark Attendance
class _MarkAttendancePage extends StatefulWidget {
  final String facultyPnr;
  final String facultyName;
  final String subject;
  const _MarkAttendancePage({
    required this.facultyPnr,
    required this.facultyName,
    required this.subject,
  });

  @override
  State<_MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<_MarkAttendancePage> {
  TimetableEntry? _selectedEntry;
  AttendanceRecord? _todayRecord;
  List<TimetableEntry> _assignedEntries = [];
  bool _isLoadingEntries = true;
  bool _isLoadingStudents = false;
  bool _isSubmitting = false;
  final Map<String, String> _attendanceMap = {}; // PNR -> 'Present' / 'Absent'
  List<AppUser> _studentsInClass = [];

  @override
  void initState() {
    super.initState();
    _loadAssignedSubjects();
  }

  Future<void> _loadAssignedSubjects() async {
    try {
      final entries = await DatabaseService()
          .getTimetableForFaculty(widget.facultyPnr)
          .first;

      // Filter unique combinations of subject, className, year, semester, branch, and batchName
      final seen = <String>{};
      final uniqueEntries = <TimetableEntry>[];
      for (var entry in entries) {
        final key =
            '${entry.subject}_${entry.className}_${entry.year}_${entry.semesterNumber}_${entry.branch}_${entry.batchName ?? "all"}';
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueEntries.add(entry);
        }
      }

      setState(() {
        _assignedEntries = uniqueEntries;
        _isLoadingEntries = false;
      });
    } catch (e) {
      setState(() => _isLoadingEntries = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subjects: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudentsForClass(TimetableEntry entry) async {
    setState(() {
      _isLoadingStudents = true;
      _attendanceMap.clear();
      _studentsInClass = [];
      _todayRecord = null;
    });

    try {
      final students = await DatabaseService().getStudentsByClass(
        entry.className,
        semester: entry.semesterNumber,
        branch: entry.branch,
        year: entry.year.toString(),
        batch: entry.batchName,
      );

      setState(() {
        _studentsInClass = students;
        for (var student in students) {
          _attendanceMap[student.pnr] = 'Absent'; // Default to absent
        }
        _isLoadingStudents = false;
      });

      await _loadTodayAttendance(entry);
    } catch (e) {
      setState(() => _isLoadingStudents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _canEditTodayRecord {
    final record = _todayRecord;
    if (record == null) return true;
    final now = DateTime.now();
    if (!_isSameDay(record.date, now)) return false;
    return now.difference(record.createdAt) <= const Duration(hours: 6);
  }

  Future<void> _loadTodayAttendance(TimetableEntry entry) async {
    try {
      final record = await DatabaseService().getTodayAttendance(
        subject: entry.subject,
        className: entry.className,
        semesterNumber: entry.semesterNumber,
        branch: entry.branch,
        year: entry.year,
        facultyPnr: widget.facultyPnr,
        batchKey: (entry.batchName ?? '').trim(),
      );

      if (!mounted) return;
      if (record == null) {
        setState(() => _todayRecord = null);
        return;
      }

      setState(() {
        _todayRecord = record;
        for (final student in _studentsInClass) {
          final pnr = student.pnr;
          _attendanceMap[pnr] = record.records[pnr] ?? 'Absent';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading today's attendance: $e")),
        );
      }
    }
  }

  void _toggleStudentStatus(String pnr) {
    setState(() {
      if (_attendanceMap[pnr] == 'Present') {
        _attendanceMap[pnr] = 'Absent';
      } else {
        _attendanceMap[pnr] = 'Present';
      }
    });
  }

  Future<void> _submitAttendance() async {
    if (_selectedEntry == null || _attendanceMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a subject and ensure students are loaded.'),
        ),
      );
      return;
    }

    if (!_canEditTodayRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance is locked (edit window expired).'),
        ),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final dateOnly = DateTime(now.year, now.month, now.day);
      final existing = _todayRecord;

      final record = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: dateOnly,
        createdAt: existing?.createdAt ?? now,
        updatedAt: existing != null ? now : null,
        subject: _selectedEntry!.subject,
        facultyPnr: widget.facultyPnr,
        facultyName: widget.facultyName,
        className: _selectedEntry!.className,
        startTime: _selectedEntry!.startTime,
        endTime: _selectedEntry!.endTime,
        semesterNumber: _selectedEntry!.semesterNumber,
        year: _selectedEntry!.year,
        branch: _selectedEntry!.branch,
        batch: _selectedEntry!.batchName,
        records: _attendanceMap,
      );
      await DatabaseService().upsertTodayAttendance(record);

      // --- NEW: Absence Alerts (Spec 6.1) ---
      _attendanceMap.forEach((pnr, status) {
        if (status == 'Absent') {
          DatabaseService().sendNotification(
            pnr,
            'Absence Alert',
            'You were marked ABSENT for ${record.subject} today.',
          );
          // Optional: Send to parent would go here if phone numbers were integrated with an SMS gateway
        }
      });
      // ------------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? 'Attendance Saved Successfully!'
                  : 'Attendance Updated Successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _todayRecord = record;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEntries) {
      return const SkeletonListView(itemCount: 8);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Assigned Subject/Class',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_assignedEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No subjects assigned to you in the timetable.'),
            )
          else
            DropdownButtonFormField<TimetableEntry>(
              initialValue: _selectedEntry,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.book),
              ),
              hint: const Text('Choose Subject - Class'),
              items: _assignedEntries.map((entry) {
                return DropdownMenuItem<TimetableEntry>(
                  value: entry,
                  child: Text(
                    entry.batchName != null
                        ? '${entry.subject} (${entry.className} - ${entry.batchName})'
                        : '${entry.subject} (${entry.className})',
                  ),
                );
              }).toList(),
              onChanged: (entry) {
                if (entry != null) {
                  setState(() => _selectedEntry = entry);
                  _loadStudentsForClass(entry);
                }
              },
            ),
          const SizedBox(height: 24),
          if (_selectedEntry != null) ...[
            if (_todayRecord != null) ...[
              Text(
                _canEditTodayRecord
                    ? 'Today\'s attendance saved. You can edit for 6 hours.'
                    : 'Today\'s attendance is locked.',
                style: TextStyle(
                  color: _canEditTodayRecord ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Student List',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_isLoadingStudents)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SkeletonListView(
                  itemCount: 6,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              )
            else if (_studentsInClass.isEmpty)
              const Center(child: Text('No students found for this class.'))
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _studentsInClass.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    final student = _studentsInClass[index];
                    final pnr = student.pnr;
                    final status = _attendanceMap[pnr] ?? 'Present';
                    final isPresent = status == 'Present';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Center(
                              child: Text(
                                (student.rollNo?.trim().isNotEmpty ?? false)
                                    ? student.rollNo!.trim()
                                    : '-',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'PNR: $pnr',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                isPresent ? 'PRESENT' : 'ABSENT',
                                style: TextStyle(
                                  color: isPresent ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: isPresent,
                                onChanged: _canEditTodayRecord
                                    ? (val) => _toggleStudentStatus(pnr)
                                    : null,
                                activeThumbColor: Colors.white,
                                activeTrackColor: Colors.green,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            if (_studentsInClass.isNotEmpty)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_canEditTodayRecord && !_isSubmitting)
                      ? _submitAttendance
                      : null,
                  icon: const Icon(Icons.save),
                  label: Text(
                    _todayRecord == null
                        ? 'Save Today\'s Attendance'
                        : _canEditTodayRecord
                        ? 'Update Today\'s Attendance'
                        : 'Attendance Locked',
                  ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_ind,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a subject above to load student list',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _AttendanceSheetPage extends StatefulWidget {
  final String facultyPnr;
  const _AttendanceSheetPage({required this.facultyPnr});

  @override
  State<_AttendanceSheetPage> createState() => _AttendanceSheetPageState();
}

class _AttendanceSheetPageState extends State<_AttendanceSheetPage> {
  TimetableEntry? _selectedEntry;
  List<TimetableEntry> _assignedEntries = [];
  bool _isLoadingEntries = true;
  bool _isLoadingReport = false;
  String? _error;

  List<AppUser> _students = [];
  List<AttendanceRecord> _records = [];
  List<String> _dateKeys = [];

  @override
  void initState() {
    super.initState();
    _loadAssignedSubjects();
  }

  Future<void> _loadAssignedSubjects() async {
    try {
      final entries = await DatabaseService()
          .getTimetableForFaculty(widget.facultyPnr)
          .first;

      final seen = <String>{};
      final uniqueEntries = <TimetableEntry>[];
      for (var entry in entries) {
        final key =
            '${entry.subject}_${entry.className}_${entry.year}_${entry.semesterNumber}_${entry.branch}_${entry.batchName ?? "all"}';
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueEntries.add(entry);
        }
      }

      if (!mounted) return;
      setState(() {
        _assignedEntries = uniqueEntries;
        _isLoadingEntries = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingEntries = false;
        _error = 'Error loading subjects: $e';
      });
    }
  }

  String _shortDate(String dateKey) {
    // yyyy-MM-dd -> dd/MM
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    return '${parts[2]}/${parts[1]}';
  }

  Future<void> _getReport() async {
    final entry = _selectedEntry;
    if (entry == null) {
      setState(() => _error = 'Please select a subject/class first.');
      return;
    }

    setState(() {
      _isLoadingReport = true;
      _error = null;
      _students = [];
      _records = [];
      _dateKeys = [];
    });

    try {
      final students = await DatabaseService().getStudentsByClass(
        entry.className,
        semester: entry.semesterNumber,
        branch: entry.branch,
        year: entry.year.toString(),
        batch: entry.batchName,
      );

      final allRecords = await DatabaseService().getAttendanceForSubject(
        entry.subject,
        entry.className,
        entry.semesterNumber,
        branch: entry.branch,
        year: entry.year,
      );

      final batchKey = (entry.batchName ?? '').trim();
      final filteredRecords =
          allRecords.where((r) => (r.batchKey.trim()) == batchKey).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      final dateKeys = <String>{};
      for (final r in filteredRecords) {
        dateKeys.add(r.dateKey);
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _records = filteredRecords;
        _dateKeys = dateKeys.toList()..sort();
        _isLoadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingReport = false;
        _error = 'Error generating report: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEntries) {
      return const SkeletonListView(itemCount: 8);
    }

    if (_error != null && _assignedEntries.isEmpty) {
      return Center(child: Text(_error!));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Subject/Class',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_assignedEntries.isEmpty)
            const Text('No subjects assigned to you in the timetable.')
          else
            DropdownButtonFormField<TimetableEntry>(
              initialValue: _selectedEntry,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.book),
              ),
              hint: const Text('Choose Subject - Class'),
              items: _assignedEntries.map((entry) {
                return DropdownMenuItem<TimetableEntry>(
                  value: entry,
                  child: Text(
                    entry.batchName != null
                        ? '${entry.subject} (${entry.className} - ${entry.batchName})'
                        : '${entry.subject} (${entry.className})',
                  ),
                );
              }).toList(),
              onChanged: (entry) {
                setState(() => _selectedEntry = entry);
              },
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isLoadingReport ? null : _getReport,
              icon: const Icon(Icons.download),
              label: const Text('Get Report'),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingReport
                ? const SkeletonListView(
                    itemCount: 10,
                    padding: EdgeInsets.zero,
                  )
                : _students.isEmpty || _dateKeys.isEmpty
                ? const Center(child: Text('No attendance records found.'))
                : _buildTable(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final recordByDate = <String, AttendanceRecord>{};
    for (final r in _records) {
      recordByDate[r.dateKey] = r;
    }

    final sortedStudents = [..._students]
      ..sort((a, b) {
        final ra = int.tryParse(a.rollNo ?? '');
        final rb = int.tryParse(b.rollNo ?? '');
        if (ra != null && rb != null) return ra.compareTo(rb);
        return (a.rollNo ?? '').compareTo(b.rollNo ?? '');
      });

    final columns = <DataColumn>[
      const DataColumn(label: Text('Roll')),
      const DataColumn(label: Text('Name')),
      const DataColumn(label: Text('PNR')),
      ..._dateKeys.map((d) => DataColumn(label: Text(_shortDate(d)))),
      const DataColumn(label: Text('Total')),
      const DataColumn(label: Text('%')),
    ];

    final rows = sortedStudents.map((student) {
      final pnr = student.pnr;
      int present = 0;
      final cells = <DataCell>[
        DataCell(
          Text(
            (student.rollNo?.trim().isNotEmpty ?? false)
                ? student.rollNo!.trim()
                : '-',
          ),
        ),
        DataCell(Text(student.name)),
        DataCell(Text(pnr)),
      ];

      for (final d in _dateKeys) {
        final rec = recordByDate[d];
        final status = rec?.records[pnr] ?? 'Absent';
        if (status == 'Present') present++;
        cells.add(DataCell(Text(status == 'Present' ? 'P' : 'A')));
      }

      final total = _dateKeys.length;
      final percent = total == 0 ? 0.0 : (present / total) * 100;
      cells.add(DataCell(Text('$present/$total')));
      cells.add(DataCell(Text(percent.toStringAsFixed(1))));
      return DataRow(cells: cells);
    }).toList();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: rows,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columnSpacing: 16,
        ),
      ),
    );
  }
}

// Sub-page: Resolve Disputes
class _ResolveDisputesPage extends StatelessWidget {
  final String facultySubject;
  final String facultyPnr;
  const _ResolveDisputesPage({
    required this.facultySubject,
    required this.facultyPnr,
  });

  @override
  Widget build(BuildContext context) {
    if (facultySubject.isEmpty) {
      return const Center(child: Text('No subject assigned.'));
    }

    return StreamBuilder<List<Dispute>>(
      stream: DatabaseService().getActiveDisputesForFacultyPnr(
        facultySubject,
        facultyPnr,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonListView(itemCount: 8);
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No active disputes',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Disputes are visible only during the 20-minute window.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final disputes = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: disputes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final dispute = disputes[index];
            return Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.10),
                      Colors.white,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PNR: ${dispute.studentPnr}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy',
                                  ).format(dispute.date),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_top_outlined,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DisputeMetaPill(
                            icon: Icons.book_outlined,
                            text: dispute.subject,
                          ),
                          if ((dispute.className ?? '').trim().isNotEmpty)
                            _DisputeMetaPill(
                              icon: Icons.class_outlined,
                              text: dispute.className!.trim(),
                            ),
                          if ((dispute.lectureStartTime ?? '')
                                  .trim()
                                  .isNotEmpty &&
                              (dispute.lectureEndTime ?? '').trim().isNotEmpty)
                            _DisputeMetaPill(
                              icon: Icons.schedule_outlined,
                              text:
                                  '${dispute.lectureStartTime} – ${dispute.lectureEndTime}',
                            ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REASON FOR DISPUTE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dispute.reason,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await DatabaseService().resolveDispute(
                                    dispute.id,
                                    'Approved',
                                    dispute.studentPnr,
                                    dispute.subject,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Attendance updated to Present',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await DatabaseService().resolveDispute(
                                    dispute.id,
                                    'Rejected',
                                    dispute.studentPnr,
                                    dispute.subject,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Dispute rejected'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
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
          },
        );
      },
    );
  }
}

class _DisputeMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DisputeMetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[900],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
