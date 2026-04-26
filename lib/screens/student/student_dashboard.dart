import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/dispute_model.dart';
import '../../models/timetable_entry.dart';
import '../../models/user_model.dart';
import '../../utils/college_data.dart';
import '../../utils/skeleton.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/notification_model.dart';
import '../notifications_screen.dart';
import '../classroom/classroom_gate_screen.dart';
import 'student_application_screens.dart';
import 'student_ise_screen.dart';
import 'student_disputes_screen.dart';
import '../../services/assignment_reminder_service.dart';
import '../../widgets/sidebar_profile_header.dart';
import '../../widgets/sidebar_nav_item.dart';

class StudentDashboard extends StatefulWidget {
  final int initialIndex;
  const StudentDashboard({super.key, this.initialIndex = 0});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  String? _cachedPnr;
  Stream<List<AppNotification>>? _notificationStream;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final Set<int> _visitedTabs;
  String? _profilePhotoBase64;
  bool _isSavingProfilePhoto = false;
  String? _sidebarBgBase64;
  bool _isSavingSidebarBg = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visitedTabs = <int>{widget.initialIndex.clamp(0, 3)};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().currentUser;
    if (user != null && user.pnr != _cachedPnr) {
      _cachedPnr = user.pnr;
      _notificationStream = DatabaseService().getNotifications(user.pnr);
      _loadProfilePhotoPath(user.pnr);
      _loadSidebarBackground(user.pnr);
      AssignmentReminderService.startForStudent(user);
    }
  }

  Future<void> _loadProfilePhotoPath(String pnr) async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('student_profile_photo_b64_$pnr');
    if (!mounted) return;
    setState(() => _profilePhotoBase64 = b64);
  }

  Future<void> _loadSidebarBackground(String pnr) async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('student_sidebar_bg_b64_$pnr');
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
      await prefs.setString('student_profile_photo_b64_$pnr', b64);

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
      await prefs.setString('student_sidebar_bg_b64_$pnr', b64);

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

  void _pushSidebarPage(Widget page) {
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => route.settings.name == '/student_dashboard' || route.isFirst,
    );
  }

  void _openProfile(AppUser user) {
    _pushSidebarPage(
      StudentProfileScreen(userPnr: user.pnr),
    );
  }

  void _openNotifications(String pnr) {
    _pushSidebarPage(
      NotificationScreen(pnr: pnr),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    const pageCount = 4;
    final safeIndex = _currentIndex >= pageCount ? 0 : _currentIndex;

    final List<Widget> pages = [
      _visitedTabs.contains(0)
          ? _StudentDashboardPage(user: user)
          : const SizedBox.shrink(),
      _visitedTabs.contains(1)
          ? _StudentAttendanceDetailPage(user: user)
          : const SizedBox.shrink(),
      _visitedTabs.contains(2)
          ? _RaiseDisputePage(studentPnr: user.pnr)
          : const SizedBox.shrink(),
      _visitedTabs.contains(3)
          ? _StudentTimetableTab(user: user)
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
                onPressed: () => _openNotifications(user.pnr),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
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
                  subtitle: 'Student',
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
              SidebarNavItem(
                label: 'Dashboard',
                icon: Icons.dashboard_outlined,
                selected: safeIndex == 0,
                onTap: () => _selectTab(0),
              ),
              SidebarNavItem(
                label: 'Attendance',
                icon: Icons.analytics_outlined,
                selected: safeIndex == 1,
                onTap: () => _selectTab(1),
              ),
              SidebarNavItem(
                label: 'Timetable',
                icon: Icons.table_chart_outlined,
                selected: safeIndex == 3,
                onTap: () => _selectTab(3),
              ),
              SidebarNavItem(
                label: 'ISE',
                icon: Icons.grading_outlined,
                selected: false,
                onTap: () {
                  _pushSidebarPage(
                    StudentIseScreen(studentPnr: user.pnr),
                  );
                },
              ),
              SidebarNavItem(
                label: 'Disputes',
                icon: Icons.report_problem_outlined,
                selected: false,
                onTap: () {
                  _pushSidebarPage(
                    const StudentDisputesScreen(),
                  );
                },
              ),
              SidebarNavItem(
                label: 'Applications',
                icon: Icons.assignment_outlined,
                selected: false,
                onTap: () {
                  _pushSidebarPage(
                    StudentApplicationsScreen(student: user),
                  );
                },
              ),
              SidebarNavItem(
                label: 'Go To Classroom',
                icon: Icons.meeting_room_outlined,
                selected: false,
                onTap: () {
                  _pushSidebarPage(
                    const ClassroomGateScreen(),
                  );
                },
              ),
              SidebarNavItem(
                label: 'Profile',
                icon: Icons.account_circle_outlined,
                selected: false,
                onTap: () {
                  _openProfile(user);
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
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    _visitedTabs.add(index);
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }
}

class _StudentTimetableTab extends StatefulWidget {
  final AppUser user;
  const _StudentTimetableTab({required this.user});

  @override
  State<_StudentTimetableTab> createState() => _StudentTimetableTabState();
}

class _StudentTimetableTabState extends State<_StudentTimetableTab> {
  bool _isLoading = false;
  List<TimetableEntry> _timetable = [];
  final List<String> _days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final Map<String, GlobalKey> _dayKeys = {
    'Monday': GlobalKey(),
    'Tuesday': GlobalKey(),
    'Wednesday': GlobalKey(),
    'Thursday': GlobalKey(),
    'Friday': GlobalKey(),
    'Saturday': GlobalKey(),
  };
  final ScrollController _scrollController = ScrollController();

  bool get _hasSaturdayClasses => _timetable.any(
        (e) => e.day.toLowerCase() == 'saturday',
      );

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final branch = widget.user.branch;
    final year = widget.user.year != null
        ? int.tryParse(widget.user.year!)
        : null;
    final semester = widget.user.semester;
    final className = widget.user.effectiveClassName;

    if (branch == null || year == null || semester == null || className == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService().getTimetableBySemester(
        branch,
        year,
        semester,
        className: className,
      );
      if (!mounted) return;
      setState(() {
        _timetable = data;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _scrollToToday() {
    final now = DateTime.now();
    // DateTime weekday: Monday=1, Sunday=7
    var todayName =
        now.weekday >= 1 && now.weekday <= 6 ? _days[now.weekday - 1] : _days.first;

    // If Saturday has no classes, don't try to scroll to a blank card.
    if (todayName == 'Saturday' && !_hasSaturdayClasses) {
      todayName = 'Friday';
    }

    final key = _dayKeys[todayName];
    if (key == null) return;
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      alignment: 0.1,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysToShow = _hasSaturdayClasses
        ? _days
        : _days.where((d) => d.toLowerCase() != 'saturday').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Full Weekly Timetable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const SkeletonListView(itemCount: 8, padding: EdgeInsets.all(12))
              : _timetable.isEmpty
                  ? const Center(
                      child: Text('No timetable found for your branch/year.'),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: daysToShow.map((day) {
                          final entries = _timetable
                              .where((e) =>
                                  e.day.toLowerCase() == day.toLowerCase())
                              .toList()
                            ..sort((a, b) {
                              try {
                                return DateFormat('hh:mm a')
                                    .parse(a.startTime)
                                    .compareTo(
                                      DateFormat('hh:mm a').parse(b.startTime),
                                    );
                              } catch (_) {
                                return a.startTime.compareTo(b.startTime);
                              }
                            });

                          return Container(
                            key: _dayKeys[day],
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.08),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        day,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color:
                                              Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      Text(
                                        '${entries.length} classes',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (entries.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No classes scheduled',
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  Column(
                                    children: entries.map((entry) {
                                      final isPractical =
                                          entry.batchName != null;
                                      return ListTile(
                                        dense: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        leading: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.startTime,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'to ${entry.endTime}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        title: Text(
                                          entry.subject,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.facultyName,
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (isPractical)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(top: 4),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Batch: ${entry.batchName}',
                                                    style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            entry.className,
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _UpcomingLectureItem {
  final String id; // unique per occurrence (dateKey+timetableId or eventId)
  final DateTime date;
  final String dateKey;
  final String subject;
  final String facultyName;
  final String className;
  final String startTime;
  final String endTime;
  final String? batchName;
  final bool isExtra;
  final bool isCancelled;
  final String? timetableEntryId;

  const _UpcomingLectureItem({
    required this.id,
    required this.date,
    required this.dateKey,
    required this.subject,
    required this.facultyName,
    required this.className,
    required this.startTime,
    required this.endTime,
    required this.batchName,
    required this.isExtra,
    required this.isCancelled,
    required this.timetableEntryId,
  });
}

// Main Dashboard Page showing upcoming schedule and overall stats
class _StudentDashboardPage extends StatefulWidget {
  final AppUser user;
  const _StudentDashboardPage({required this.user});

  @override
  State<_StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<_StudentDashboardPage> {
  bool _isLoading = false;
  List<TimetableEntry> _timetable = [];
  Timer? _reminderTimer;
  final Set<String> _remindedLectures =
      {}; // Prevent multiple reminders for same lecture

  @override
  void initState() {
    super.initState();
    if (_hasTimetableProfile(widget.user)) {
      _loadTimetable();
      _startReminderSystem();
    }
  }

  void _startReminderSystem() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkUpcomingLectures();
      // Auto-refresh the UI every minute to update the "Upcoming Lectures" list
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _checkUpcomingLectures() {
    if (_timetable.isEmpty) return;

    final now = DateTime.now();
    final todayKey = _dateKeyFromDate(now);
    final todayLectures = _getUpcomingLectures()
        .where((l) => l.dateKey == todayKey && !l.isCancelled)
        .toList();

    for (final lecture in todayLectures) {
      try {
        final startTimeParsed = DateFormat('hh:mm a').parse(lecture.startTime);
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
            !_remindedLectures.contains(lecture.id)) {
          _remindedLectures.add(lecture.id);
          DatabaseService().sendNotification(
            widget.user.pnr,
            'Upcoming Lecture Reminder',
            'Your ${lecture.subject} lecture starts in $difference minutes!',
          );
        }
      } catch (e) {
        debugPrint('Error in reminder system: $e');
      }
    }
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StudentDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final profileChanged =
        oldWidget.user.branch != widget.user.branch ||
        oldWidget.user.year != widget.user.year ||
        oldWidget.user.semester != widget.user.semester ||
        oldWidget.user.division != widget.user.division ||
        oldWidget.user.effectiveClassName != widget.user.effectiveClassName;

    if (!profileChanged) {
      return;
    }

    if (_hasTimetableProfile(widget.user)) {
      _loadTimetable();
    } else if (_timetable.isNotEmpty) {
      setState(() {
        _timetable = [];
      });
    }
  }

  bool _hasTimetableProfile(AppUser user) {
    return (user.branch?.trim().isNotEmpty ?? false) &&
        int.tryParse(user.year ?? '') != null &&
        user.semester != null &&
        (user.division?.trim().isNotEmpty ?? false) &&
        (user.effectiveClassName?.isNotEmpty ?? false);
  }

  Future<void> _loadTimetable() async {
    final branch = widget.user.branch?.trim();
    final year = int.tryParse(widget.user.year ?? '');
    final semester = widget.user.semester;
    final className = widget.user.effectiveClassName;

    if (branch == null ||
        branch.isEmpty ||
        year == null ||
        semester == null ||
        className == null ||
        className.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final entries = await DatabaseService().getTimetableBySemester(
        branch,
        year,
        semester,
        className: className,
      );
      if (!mounted) return;
      setState(() {
        _timetable = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading timetable: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _dateKeyFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseTime(String timeString) {
    try {
      return DateFormat('hh:mm a').parse(timeString);
    } catch (_) {
      return null;
    }
  }

  List<_UpcomingLectureItem> _getUpcomingLectures() {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final dateKey = _dateKeyFromDate(date);
    final dayName = DateFormat('EEEE').format(date).toLowerCase();

    final filtered = <_UpcomingLectureItem>[];

    for (final entry in _timetable) {
      if (entry.day.toLowerCase() != dayName) continue;
      if (entry.batchName != null && entry.batchName != widget.user.batch) {
        continue;
      }

      final startTime = _parseTime(entry.startTime);
      if (startTime != null) {
        final startAt = DateTime(
          date.year,
          date.month,
          date.day,
          startTime.hour,
          startTime.minute,
        );
        if (startAt.isBefore(now)) {
          continue;
        }
      }

      filtered.add(
        _UpcomingLectureItem(
          id: '$dateKey|${entry.id}',
          date: date,
          dateKey: dateKey,
          subject: entry.subject,
          facultyName: entry.facultyName,
          className: entry.className,
          startTime: entry.startTime,
          endTime: entry.endTime,
          batchName: entry.batchName,
          isExtra: false,
          isCancelled: false,
          timetableEntryId: entry.id,
        ),
      );
    }

    filtered.sort((a, b) {
      final dc = a.dateKey.compareTo(b.dateKey);
      if (dc != 0) return dc;
      final ta = _parseTime(a.startTime);
      final tb = _parseTime(b.startTime);
      if (ta != null && tb != null) return ta.compareTo(tb);
      return a.startTime.compareTo(b.startTime);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final className = user.effectiveClassName;
    final hasTimetableProfile = _hasTimetableProfile(user);
    final upcomingLectures = _getUpcomingLectures();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB794F4),
                  Color(0xFFD6BCFA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user.name}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!hasTimetableProfile) ...[
            const SizedBox(height: 24),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Complete your profile in the Profile tab to load lectures automatically.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Lectures',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (hasTimetableProfile)
                TextButton.icon(
                  onPressed: _loadTimetable,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          !hasTimetableProfile
              ? const Center(
                  child: Text(
                    'Profile details are required before lectures can be loaded.',
                  ),
                )
              : _isLoading
              ? const SkeletonListView(
                  itemCount: 4,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                )
              : upcomingLectures.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No more lectures today.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingLectures.length,
                  itemBuilder: (context, index) {
                    final lecture = upcomingLectures[index];
                    final isPractical = lecture.batchName != null;
                    final isCancelled = lecture.isCancelled;
                    final isExtra = lecture.isExtra;
                    final todayKey = _dateKeyFromDate(DateTime.now());
                    final dateLabel = lecture.dateKey == todayKey
                        ? 'Today'
                        : DateFormat('EEE, MMM d').format(lecture.date);

                    final borderColor = isCancelled
                        ? Colors.red
                        : isExtra
                        ? Colors.purple
                        : isPractical
                        ? Colors.orange
                        : Theme.of(context).primaryColor;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border(
                          left: BorderSide(
                            color: borderColor,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Text(
                                  lecture.startTime.split(' ')[0],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  lecture.startTime.split(' ').length > 1
                                      ? lecture.startTime.split(' ')[1]
                                      : '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey[200],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lecture.subject,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      decoration: isCancelled
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color: isCancelled
                                          ? Colors.grey[600]
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      Text(
                                        lecture.facultyName,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          dateLabel,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isCancelled)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'OFF',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (!isCancelled && isExtra)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'EXTRA',
                                            style: TextStyle(
                                              color: Colors.purple,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (isPractical) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Batch: ${lecture.batchName}',
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    lecture.className,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'to ${lecture.endTime}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          Text(
            'Overall Attendance Status',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (className == null || user.semester == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Save your profile to view attendance based on your class and semester.',
                ),
              ),
            )
          else
            FutureBuilder<double>(
              future: DatabaseService().getOverallAttendance(
                user.pnr,
                className,
                user.semester!,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SkeletonBox(height: 140),
                  );
                }

                final overallPercentage = snapshot.data ?? 0.0;
                final color = overallPercentage >= 75
                    ? Colors.green
                    : overallPercentage >= 60
                    ? Colors.orange
                    : Colors.red;

                return _OverallAttendanceCard(
                  overallPercentage: overallPercentage,
                  color: color,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OverallAttendanceCard extends StatelessWidget {
  final double overallPercentage;
  final Color color;

  const _OverallAttendanceCard({
    required this.overallPercentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = overallPercentage.clamp(0.0, 100.0);
    final progress = percent / 100.0;

    final statusMessage = percent >= 75
        ? 'Good attendance. Keep attending lectures and practicals.'
        : percent >= 60
            ? 'Moderate attendance. Attend lectures and practicals regularly.'
            : 'Low attendance. Let\'s study and attend every lecture and practical.';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final ringSize = isNarrow ? 76.0 : 86.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.14),
                Colors.white,
              ],
            ),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -28,
                bottom: -28,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Overall Attendance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _ProgressRing(
                        size: ringSize,
                        color: color,
                        progress: progress,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double size;
  final Color color;
  final double progress;

  const _ProgressRing({
    required this.size,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final progressText = (value * 100).clamp(0.0, 100.0);
        final center = progressText.toStringAsFixed(progressText % 1 == 0 ? 0 : 1);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '%',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Detailed Attendance Page (weekly view)
class _StudentAttendanceDetailPage extends StatefulWidget {
  final AppUser user;
  const _StudentAttendanceDetailPage({required this.user});

  @override
  State<_StudentAttendanceDetailPage> createState() =>
      _StudentAttendanceDetailPageState();
}

class _StudentAttendanceDetailPageState
    extends State<_StudentAttendanceDetailPage> {
  bool _loading = true;
  String? _error;
  DateTime? _weekStart;
  DateTime? _weekEnd;
  int _weekNumber = 1;
  late final DatabaseService _db;
  List<_WeeklyAttendance> _weeklyStats = [];

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _loadWeeklyAttendance();
  }

  DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1)); // Monday start

  Future<void> _loadWeeklyAttendance() async {
    final user = widget.user;
    final className = user.effectiveClassName;
    final branch = user.branch;
    final semester = user.semester;
    final year = int.tryParse(user.year ?? '');

    if (className == null || branch == null || semester == null || year == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Complete your profile to view attendance.';
        _loading = false;
      });
      return;
    }

    try {
      final window = await _db.getSemesterWindow(branch, year, semester);
      if (window == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Semester dates not set by admin.';
          _loading = false;
        });
        return;
      }

      // Purge if semester is over (+2 days)
      await _db.purgeAttendanceForSemesterIfExpired(
        branch,
        year,
        semester,
        window.endDate,
      );

      if (DateTime.now().isAfter(window.endDate.add(const Duration(days: 2)))) {
        if (!mounted) return;
        setState(() {
          _error = 'Semester ended. Attendance records cleared.';
          _loading = false;
        });
        return;
      }

      final today = DateTime.now();
      DateTime weekStart = _startOfWeek(today);
      if (weekStart.isBefore(_startOfWeek(window.startDate))) {
        weekStart = _startOfWeek(window.startDate);
      }
      DateTime weekEnd = weekStart.add(const Duration(days: 5));
      if (weekEnd.isAfter(window.endDate)) {
        weekEnd = window.endDate;
      }

      final semStartWeek = _startOfWeek(window.startDate);
      _weekNumber = ((weekStart.difference(semStartWeek).inDays) / 7).floor() + 1;

      final semesterRecords = await _db.getAttendanceForClass(
        className,
        semester,
        branch,
        start: window.startDate,
        end: window.endDate,
      );

      final weeklyStats = <_WeeklyAttendance>[];
      DateTime currentWeekStart = _startOfWeek(window.startDate);
      int weekNumber = 1;
      while (!currentWeekStart.isAfter(window.endDate)) {
        final weekRangeStart = currentWeekStart.isBefore(window.startDate)
            ? window.startDate
            : currentWeekStart;
        final weekRangeEnd = currentWeekStart.add(const Duration(days: 5));
        final actualEnd = weekRangeEnd.isAfter(window.endDate)
            ? window.endDate
            : weekRangeEnd;

        if (!weekRangeStart.isAfter(actualEnd)) {
          int weekTotal = 0;
          int weekPresent = 0;
          for (var record in semesterRecords) {
            if (record.date.isBefore(weekRangeStart) || record.date.isAfter(actualEnd)) {
              continue;
            }
            if (!record.records.containsKey(user.pnr)) continue;
            weekTotal++;
            if (record.records[user.pnr] == 'Present') {
              weekPresent++;
            }
          }

          weeklyStats.add(_WeeklyAttendance(
            weekNumber: weekNumber,
            start: weekRangeStart,
            end: actualEnd,
            present: weekPresent,
            total: weekTotal,
          ));
          weekNumber++;
        }

        currentWeekStart = currentWeekStart.add(const Duration(days: 7));
      }

      if (!mounted) return;
      setState(() {
        _weekStart = weekStart;
        _weekEnd = weekEnd;
        _weeklyStats = weeklyStats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading attendance: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonListView(itemCount: 10);
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final currentWeek = _weeklyStats.firstWhere(
      (week) => week.weekNumber == _weekNumber,
      orElse: () => _weeklyStats.isNotEmpty ? _weeklyStats.first : _WeeklyAttendance(
        weekNumber: _weekNumber,
        start: _weekStart ?? DateTime.now(),
        end: _weekEnd ?? DateTime.now(),
        present: 0,
        total: 0,
      ),
    );
    final otherWeeks = _weeklyStats
        .where((week) => week.weekNumber != currentWeek.weekNumber)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadWeeklyAttendance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Current week: $_weekNumber',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _loadWeeklyAttendance,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_weekStart != null && _weekEnd != null)
            Text(
              '${DateFormat('dd MMM yyyy').format(_weekStart!)} - ${DateFormat('dd MMM yyyy').format(_weekEnd!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 24),
          Text(
            'Weekly Report',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_weeklyStats.isEmpty)
            Center(
              child: Text(
                'No weekly attendance records available.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...[
            _WeeklyReportCard(week: currentWeek),
            const SizedBox(height: 16),
            for (final week in otherWeeks) ...[
              _WeeklyReportCard(week: week),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

}

class _WeeklyAttendance {
  final int weekNumber;
  final DateTime start;
  final DateTime end;
  final int present;
  final int total;

  _WeeklyAttendance({
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.present,
    required this.total,
  });

  double get percent => total == 0 ? 0 : (present / total) * 100;
}

class _WeeklyReportCard extends StatelessWidget {
  final _WeeklyAttendance week;

  const _WeeklyReportCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM');
    final color = week.percent >= 75
        ? Colors.green
        : week.percent >= 60
            ? Colors.orange
            : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week ${week.weekNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${week.percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${df.format(week.start)} - ${df.format(week.end)}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  week.total == 0 ? 'No classes' : '${week.present}/${week.total} present',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                week.total == 0 ? 'No classes' : '${week.total} classes',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StudentProfileScreen extends StatefulWidget {
  final String userPnr;

  const StudentProfileScreen({super.key, required this.userPnr});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pnrController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _yearController = TextEditingController();
  final _semesterController = TextEditingController();
  final _branchController = TextEditingController();
  final _divisionController = TextEditingController();
  String? _selectedBatch;

  bool _isEditing = false;
  bool _isSaving = false;
  String? _syncedForPnr;

  @override
  void initState() {
    super.initState();
    _pnrController.text = widget.userPnr;
    _yearController.addListener(_handleYearChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return;
    if (user.pnr != widget.userPnr) return;
    if (_isEditing) return;
    if (_syncedForPnr == user.pnr) return;
    _syncedForPnr = user.pnr;
    _syncControllers(user);
  }

  int _parsedYear() {
    final parsed = int.tryParse(_yearController.text.trim());
    return parsed ?? 1;
  }

  void _handleYearChange() {
    final divisions = CollegeData.divisionsForYear(_parsedYear());
    final current = _divisionController.text.trim().toUpperCase();
    if (current.isNotEmpty && !divisions.contains(current)) {
      setState(() => _divisionController.text = '');
    }
  }

  void _syncControllers(AppUser user) {
    _pnrController.text = user.pnr;
    _nameController.text = user.name;
    _dobController.text = user.dob?.toString() ?? '';
    _rollNoController.text = user.rollNo?.toString() ?? '';
    _yearController.text = user.year?.toString() ?? '';
    _semesterController.text = user.semester?.toString() ?? '';
    _branchController.text = user.branch?.toString() ?? '';
    _divisionController.text = user.division?.toString() ?? '';
    _selectedBatch = user.batch?.toString();
    _phoneController.text = user.phone?.toString() ?? '';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }


  Future<void> _scanQrAndPrefill() async {
    if (_isSaving) {
      return;
    }

    final scanned = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const _QrJsonScannerScreen()),
    );

    if (!mounted || scanned == null) {
      return;
    }

    String? readKey(String key) {
      for (final entry in scanned.entries) {
        if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
          return entry.value?.toString();
        }
      }
      return null;
    }

    final scannedPnr = readKey('pnr')?.trim();
    if (scannedPnr != null &&
        scannedPnr.isNotEmpty &&
        scannedPnr != widget.userPnr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanned PNR does not match the logged-in student.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    final scannedName = readKey('name');
    final scannedDob = readKey('dob');
    final scannedBranch = readKey('branch');

    setState(() {
      _isEditing = true;

      if (scannedPnr != null &&
          scannedPnr.isNotEmpty &&
          scannedPnr == widget.userPnr) {
        _pnrController.text = scannedPnr;
      }
      if (scannedName != null && scannedName.trim().isNotEmpty) {
        _nameController.text = scannedName.trim();
      }
      if (scannedDob != null && scannedDob.trim().isNotEmpty) {
        _dobController.text = scannedDob.trim();
      }
      if (scannedBranch != null && scannedBranch.trim().isNotEmpty) {
        _branchController.text = scannedBranch.trim().toUpperCase();
      }
    });
  }

  Future<void> _pickDob() async {
    if (!_isEditing || _isSaving) {
      return;
    }

    DateTime initialDate = DateTime(2005, 1, 1);
    final raw = _dobController.text.trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      initialDate = parsed;
    } else {
      try {
        initialDate = DateFormat('dd/MM/yyyy').parseStrict(raw);
      } catch (_) {}
      try {
        initialDate = DateFormat('yyyy-MM-dd').parseStrict(raw);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime.now(),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final branch = _branchController.text.trim().toUpperCase();
    final division = _divisionController.text.trim().toUpperCase();
    final className = '$branch-$division';
    final dob = _dobController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      await DatabaseService().updateStudentProfile(widget.userPnr, {
        'name': _nameController.text.trim(),
        if (dob.isNotEmpty) 'dob': dob,
        'rollNo': _rollNoController.text.trim(),
        if (phone.isNotEmpty) 'phone': phone,
        'year': _yearController.text.trim(),
        'semester': int.parse(_semesterController.text.trim()),
        'branch': branch,
        'division': division,
        'batch': _selectedBatch,
        'className': className,
      });

      if (!mounted) {
        return;
      }

      await context.read<AuthService>().refreshCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = !_isEditing || _isSaving;
    final branchNormalized = _branchController.text.trim().toUpperCase();
    final branchValue = CollegeData.branches.contains(branchNormalized)
        ? branchNormalized
        : null;

    final yearParsed = _parsedYear();
    final yearValue =
        CollegeData.years.contains(yearParsed) ? yearParsed : null;
    final semesterParsed = int.tryParse(_semesterController.text.trim());
    final semesterValue =
        CollegeData.semesters.contains(semesterParsed) ? semesterParsed : null;

    final divisions = CollegeData.divisionsForYear(yearParsed);
    final divisionNormalized = _divisionController.text.trim().toUpperCase();
    final divisionValue = divisions.contains(divisionNormalized)
        ? divisionNormalized
        : null;

    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WITClassroom'),
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit),
              onPressed: _isSaving ? null : () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: _isSaving || user == null
                  ? null
                  : () {
                      setState(() {
                        _isEditing = false;
                        _syncControllers(user);
                      });
                    },
            ),
        ],
      ),
      bottomNavigationBar: !_isEditing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  onPressed: _scanQrAndPrefill,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        readOnly: isReadOnly,
                        decoration: _inputDecoration('Student Name'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pnrController,
                        readOnly: true,
                        decoration: _inputDecoration('PNR'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        decoration: _inputDecoration('DOB (Optional)').copyWith(
                          suffixIcon: IconButton(
                            tooltip: 'Pick date',
                            icon: const Icon(Icons.calendar_month_outlined),
                            onPressed: !_isEditing || _isSaving ? null : _pickDob,
                          ),
                        ),
                        onTap: !_isEditing || _isSaving ? null : _pickDob,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rollNoController,
                        readOnly: isReadOnly,
                        decoration: _inputDecoration('Roll No'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        readOnly: isReadOnly,
                        decoration: _inputDecoration('Mobile Number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final normalized = value.trim();
                          final valid = RegExp(r'^\+?[0-9 ]{7,15}\$')
                              .hasMatch(normalized);
                          return valid ? null : 'Enter a valid phone number';
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: yearValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Current Studying Year'),
                        items: CollegeData.years
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text('$year'),
                              ),
                            )
                            .toList(),
                        onChanged: isReadOnly
                            ? null
                            : (val) {
                                setState(() => _yearController.text =
                                    val?.toString() ?? '');
                              },
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: semesterValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Semester'),
                        items: CollegeData.semesters
                            .map(
                              (sem) => DropdownMenuItem(
                                value: sem,
                                child: Text('$sem'),
                              ),
                            )
                            .toList(),
                        onChanged: isReadOnly
                            ? null
                            : (val) {
                                setState(() => _semesterController.text =
                                    val?.toString() ?? '');
                              },
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: branchValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Branch'),
                        items: CollegeData.branches
                            .map(
                              (branch) => DropdownMenuItem(
                                value: branch,
                                child: Text(branch),
                              ),
                            )
                            .toList(),
                        onChanged: isReadOnly
                            ? null
                            : (val) {
                                setState(() => _branchController.text = val ?? '');
                              },
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: divisionValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Division'),
                        items: divisions
                            .map(
                              (division) => DropdownMenuItem(
                                value: division,
                                child: Text(division),
                              ),
                            )
                            .toList(),
                        onChanged: isReadOnly
                            ? null
                            : (val) {
                                setState(() => _divisionController.text =
                                    val ?? '');
                              },
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBatch,
                        decoration: _inputDecoration('Practical Batch'),
                        items: ['B1', 'B2', 'B3'].map((batch) {
                          return DropdownMenuItem(
                            value: batch,
                            child: Text(batch),
                          );
                        }).toList(),
                        onChanged: isReadOnly
                            ? null
                            : (val) => setState(() => _selectedBatch = val),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      if (_isEditing) const SizedBox(height: 76),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _yearController.removeListener(_handleYearChange);
    _pnrController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _rollNoController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    _branchController.dispose();
    _divisionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class _QrJsonScannerScreen extends StatefulWidget {
  const _QrJsonScannerScreen();

  @override
  State<_QrJsonScannerScreen> createState() => _QrJsonScannerScreenState();
}

class _QrJsonScannerScreenState extends State<_QrJsonScannerScreen> {
  bool _handled = false;
  late final MobileScannerController _controller;
  bool _invalidShown = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 150,
      autoZoom: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isInitialized || !state.isRunning) {
                return const SizedBox.shrink();
              }

              final torchUnavailable =
                  state.torchState == TorchState.unavailable;

              return IconButton(
                tooltip: 'Torch',
                onPressed: torchUnavailable ? null : _controller.toggleTorch,
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final edge = (size.width * 0.72).clamp(220.0, 320.0);
          final scanWindow = Rect.fromCenter(
            center: size.center(Offset.zero),
            width: edge,
            height: edge,
          );

          return Stack(
            children: [
              ExcludeSemantics(
                child: MobileScanner(
                  controller: _controller,
                  // Scan the full camera frame for better reliability.
                  // The scanWindow is still used for the UI overlay only.
                  scanWindow: null,
                  tapToFocus: true,
                  overlayBuilder: (context, constraints) {
                    return ScanWindowOverlay(
                      controller: _controller,
                      scanWindow: scanWindow,
                      borderRadius: BorderRadius.circular(16),
                      borderWidth: 3,
                    );
                  },
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              error.errorCode.message,
                              textAlign: TextAlign.center,
                            ),
                            if (error.errorDetails?.message case final String msg)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  msg,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  onDetect: (capture) {
                    if (_handled) {
                      return;
                    }

                    final barcode = capture.barcodes.isNotEmpty
                        ? capture.barcodes.first
                        : null;
                    final raw = barcode?.rawValue;
                    if (raw == null || raw.trim().isEmpty) {
                      return;
                    }

                    Map<String, dynamic>? decoded;
                    try {
                      final text = raw.trim();
                      final candidates = <String>[text];

                      final start = text.indexOf('{');
                      final end = text.lastIndexOf('}');
                      if (start >= 0 && end > start) {
                        candidates.add(text.substring(start, end + 1));
                      }

                      for (final candidate in candidates) {
                        try {
                          final parsed = jsonDecode(candidate);
                          if (parsed is Map<String, dynamic>) {
                            decoded = parsed;
                            break;
                          } else if (parsed is Map) {
                            decoded = parsed.map(
                              (k, v) => MapEntry(k.toString(), v),
                            );
                            break;
                          }
                        } catch (_) {}

                        // Some generators use single quotes - try a lenient pass.
                        if (decoded == null && candidate.contains("'")) {
                          try {
                            final parsed = jsonDecode(
                              candidate.replaceAll("'", "\""),
                            );
                            if (parsed is Map<String, dynamic>) {
                              decoded = parsed;
                              break;
                            } else if (parsed is Map) {
                              decoded = parsed.map(
                                (k, v) => MapEntry(k.toString(), v),
                              );
                              break;
                            }
                          } catch (_) {}
                        }
                      }
                    } catch (_) {}

                  if (decoded == null) {
                    if (!_invalidShown && mounted) {
                      _invalidShown = true;
                      setState(() {
                        _statusMessage = 'Invalid code: expected JSON';
                      });
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() => _statusMessage = null);
                          _invalidShown = false;
                        }
                      });
                    }
                    return;
                  }

                  if (!mounted) {
                    return;
                  }

                  _handled = true;
                  _controller.stop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.pop(context, decoded);
                    }
                  });
                },
              ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Align the QR/barcode inside the frame.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (_statusMessage != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 84,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// Dispute Page (updated logic)
class _RaiseDisputePage extends StatefulWidget {
  final String studentPnr;
  const _RaiseDisputePage({required this.studentPnr});

  @override
  State<_RaiseDisputePage> createState() => _RaiseDisputePageState();
}

class _RaiseDisputePageState extends State<_RaiseDisputePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  final _reasonController = TextEditingController();
  List<TimetableEntry> _studentTimetable = [];
  bool _isLoadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null ||
        user.branch == null ||
        user.year == null ||
        user.semester == null ||
        user.effectiveClassName == null) {
      if (!mounted) return;
      setState(() => _isLoadingSubjects = false);
      return;
    }

    try {
      final timetable = await DatabaseService().getTimetableBySemester(
        user.branch!,
        int.parse(user.year!),
        user.semester!,
        className: user.effectiveClassName,
      );
      if (!mounted) return;
      setState(() {
        _studentTimetable = timetable;
        _isLoadingSubjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSubjects = false);
      debugPrint('Error loading subjects for dispute: $e');
    }
  }

  bool _isWithinDisputeTime(TimetableEntry entry) {
    try {
      // Get today's date
      final now = DateTime.now();

      // Check if the entry is for today
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
      if (entry.day.toLowerCase() != currentDay) return false;

      // Parse end time (e.g., "11:00 AM")
      final endTimeParsed = DateFormat('hh:mm a').parse(entry.endTime);
      final lectureEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTimeParsed.hour,
        endTimeParsed.minute,
      );

      // Allow dispute only within 10 minutes after lecture ends
      final disputeDeadline = lectureEndTime.add(const Duration(minutes: 10));

      return now.isAfter(lectureEndTime) && now.isBefore(disputeDeadline);
    } catch (e) {
      return false;
    }
  }

  Future<void> _submitDispute() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSubject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a subject')),
        );
        return;
      }

      // Find the entry for the selected subject to check time restriction
      final entry = _studentTimetable.firstWhere(
        (e) => e.subject == _selectedSubject,
      );

      if (!_isWithinDisputeTime(entry)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Disputes can only be raised within 10 minutes after the lecture ends.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final dispute = Dispute(
          id: '',
          studentPnr: widget.studentPnr,
          subject: _selectedSubject!,
          date: DateTime.now(),
          reason: _reasonController.text.trim(),
          status: 'Pending',
        );
        await DatabaseService().raiseDispute(dispute);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dispute raised. Waiting for faculty approval.'),
            ),
          );
          _reasonController.clear();
          setState(() => _selectedSubject = null);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSubjects) {
      return const SkeletonListView(itemCount: 6);
    }

    // Get unique subjects from timetable
    final uniqueSubjects =
        _studentTimetable.map((e) => e.subject).toSet().toList()..sort();

    if (uniqueSubjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_gmailerrorred, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No subjects available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Complete your profile and ensure your timetable is uploaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade600,
                  Colors.indigo.shade600,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.report_problem, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Raise Dispute',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fast, time-limited dispute submission for today’s lecture.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(
                avatar: Icon(Icons.timer_outlined, size: 18),
                label: Text('10 min window'),
              ),
              Chip(
                avatar: Icon(Icons.today_outlined, size: 18),
                label: Text('Today only'),
              ),
              Chip(
                avatar: Icon(Icons.verified_outlined, size: 18),
                label: Text('Faculty review'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dispute details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    items: uniqueSubjects.map((subject) {
                      return DropdownMenuItem(
                        value: subject,
                        child: Text(subject),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSubject = val),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Explain what went wrong (short and clear).',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 4,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitDispute,
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Submit Dispute',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: You can submit only within 10 minutes after the lecture ends.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    AssignmentReminderService.stop();
    super.dispose();
  }
}
