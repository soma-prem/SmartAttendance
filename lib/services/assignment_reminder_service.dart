import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom_models.dart';
import '../models/user_model.dart';
import 'db_service.dart';

class AssignmentReminderService {
  static Timer? _timer;
  static String? _activeStudentPnr;

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _activeStudentPnr = null;
  }

  static void startForStudent(AppUser student) {
    if (student.role != 'student') return;
    if (_activeStudentPnr == student.pnr && _timer != null) return;

    stop();
    _activeStudentPnr = student.pnr;

    // Run immediately, then periodically so same-day reminder slots can fire.
    runOnceForStudent(student);
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      runOnceForStudent(student);
    });
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isMidnightWindow(DateTime now) {
    // Timer runs every 10 minutes, so allow a 10-minute window after midnight.
    return now.hour == 0 && now.minute < 10;
  }

  static String _fmtDue(DateTime due) {
    final hh = due.hour.toString().padLeft(2, '0');
    final mm = due.minute.toString().padLeft(2, '0');
    return '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  static String _reminderPrefKey({
    required String studentPnr,
    required String classroomId,
    required String assignmentId,
    required String kind,
    required DateTime dueDateOnly,
  }) {
    final d = dueDateOnly;
    final dateKey =
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return 'assignment_reminder_sent_${studentPnr}_${classroomId}_${assignmentId}_${kind}_$dateKey';
  }

  static Future<void> _sendOnce({
    required SharedPreferences prefs,
    required String studentPnr,
    required ClassroomRoom room,
    required ClassroomAssignment assignment,
    required String kind,
    required String title,
    required String body,
  }) async {
    final dueAt = assignment.dueAt;
    if (dueAt == null) return;

    final key = _reminderPrefKey(
      studentPnr: studentPnr,
      classroomId: room.id,
      assignmentId: assignment.id,
      kind: kind,
      dueDateOnly: _dateOnly(dueAt),
    );

    if (prefs.getBool(key) == true) return;
    await DatabaseService().sendNotification(studentPnr, title, body);
    await prefs.setBool(key, true);
  }

  static Future<void> runOnceForStudent(AppUser student) async {
    if (student.role != 'student') return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final db = FirebaseFirestore.instance;

    final membershipsSnap = await db
        .collection('classroom_memberships')
        .doc(student.pnr.trim())
        .collection('rooms')
        .get();

    if (membershipsSnap.docs.isEmpty) return;

    for (final membership in membershipsSnap.docs) {
      final classroomId = membership.id;
      final roomSnap = await db
          .collection('classrooms')
          .doc(classroomId)
          .get();

      if (!roomSnap.exists) continue;
      final room =
          ClassroomRoom.fromMap(roomSnap.id, roomSnap.data() as Map<String, dynamic>);
      if (room.isDeleted) continue;

      final assignmentsSnap = await db
          .collection('classrooms')
          .doc(classroomId)
          .collection('assignments')
          .get();

      for (final doc in assignmentsSnap.docs) {
        final assignment =
            ClassroomAssignment.fromMap(doc.id, classroomId, doc.data());
        final dueAt = assignment.dueAt;
        if (dueAt == null) continue;

        final dueDateOnly = _dateOnly(dueAt);
        final today = _dateOnly(now);
        final diffDays = dueDateOnly.difference(today).inDays;

        final baseBody =
            '${room.title}\nDue: ${_fmtDue(dueAt)}';

        if (diffDays == 1 && _isMidnightWindow(now)) {
          await _sendOnce(
            prefs: prefs,
            studentPnr: student.pnr,
            room: room,
            assignment: assignment,
            kind: 'd1_0000',
            title: 'Due tomorrow: ${assignment.title}',
            body: '$baseBody\nReminder: due tomorrow (00:00).',
          );
        } else if (diffDays == 0 && _isMidnightWindow(now)) {
          await _sendOnce(
            prefs: prefs,
            studentPnr: student.pnr,
            room: room,
            assignment: assignment,
            kind: 'd0_0000',
            title: 'Due today: ${assignment.title}',
            body: '$baseBody\nReminder: due today (00:00).',
          );
        }
      }
    }
  }
}
