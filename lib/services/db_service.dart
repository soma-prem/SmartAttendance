import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/subject_assignment.dart';
import '../models/class_coordinator_assignment.dart';
import '../models/attendance_record.dart';
import '../models/semester_window.dart';
import '../models/timetable_entry.dart';
import '../models/dispute_model.dart';
import '../models/notification_model.dart';
import '../models/lecture_event.dart';
import '../models/ise_mark.dart';
import '../models/model_answer_paper.dart';

class DatabaseService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String buildIseCourseKey({
    required String subject,
    required String className,
    required int semesterNumber,
  }) {
    final s = subject.trim();
    final c = className.trim();
    return '$s|$c|$semesterNumber';
  }

  static String buildIseDocId({
    required String courseKey,
    required String studentPnr,
  }) {
    final key = '${courseKey.trim()}|${studentPnr.trim()}';
    return base64Url.encode(utf8.encode(key));
  }

  static String _dateKeyFromParts(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static String dateKeyFromDate(DateTime date) {
    return _dateKeyFromParts(date.year, date.month, date.day);
  }

  static String dateDisplayDdMmYyyy(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().padLeft(4, '0')}';
  }

  static String? tryParseDdMmYyyyToDateKey(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    return _dateKeyFromParts(year, month, day);
  }

  static String buildModelAnswerKey({
    required String courseCode,
    required String department,
    required String className,
    required String dateKey,
    required String testNo,
  }) {
    return '${courseCode.trim()}|${department.trim()}|${className.trim()}|${dateKey.trim()}|${testNo.trim()}';
  }

  static String buildModelAnswerDocId(String key) {
    return base64Url.encode(utf8.encode(key.trim()));
  }

  String _dateKeyFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dayNameFromWeekday(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  // --- Authentication / Users ---

  Future<bool> userExists(String pnr) async {
    try {
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      throw Exception("Error checking user existence: $e");
    }
  }

  Future<AppUser?> authenticateUser(String pnr, String password) async {
    try {
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return AppUser.fromMap(snap.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception("Error authenticating: $e");
    }
  }

  Future<AppUser?> getUserByPnr(String pnr) async {
    try {
      final safe = pnr.trim();
      if (safe.isEmpty) return null;

      // Fast path: many code paths store users with docId == pnr.
      final direct = await _db.collection('users').doc(safe).get();
      if (direct.exists) {
        return AppUser.fromMap(direct.data() as Map<String, dynamic>);
      }

      // Fallback for legacy/random docId storage.
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: safe)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return AppUser.fromMap(snap.docs.first.data());
    } catch (e) {
      throw Exception("Error fetching user: $e");
    }
  }

  Future<void> registerUser(AppUser user, String password) async {
    try {
      final userDoc = _db.collection('users').doc();
      final data = user.toMap();
      data['password'] = password; // For educational mini-project purposes
      await userDoc.set(data);
    } catch (e) {
      throw Exception("Error registering: $e");
    }
  }

  // Used for self-registration (student/faculty). Creates exactly one request per PNR.
  Future<void> requestAccount(AppUser user, String password) async {
    try {
      final pnr = user.pnr.trim();
      if (pnr.isEmpty) {
        throw Exception('PNR is required');
      }
      if (pnr == 'admin') {
        throw Exception('This PNR is reserved');
      }
      if (await userExists(pnr)) {
        throw Exception(
          'Account already exists. Please login or wait for approval.',
        );
      }

      final doc = _db.collection('users').doc(pnr);
      final data = user.toMap();
      data['pnr'] = pnr;
      data['password'] = password;
      await doc.set(data);
    } catch (e) {
      throw Exception("Error requesting account: $e");
    }
  }

  Future<void> updateStudentProfile(
    String pnr,
    Map<String, dynamic> updates,
  ) async {
    try {
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        throw Exception('Student not found');
      }

      await snap.docs.first.reference.update(updates);
    } catch (e) {
      throw Exception("Error updating student profile: $e");
    }
  }

  // --- Admin ---

  Future<void> createFaculty(AppUser faculty, String password) async {
    try {
      final pnr = faculty.pnr.trim();
      if (pnr.isEmpty) {
        throw Exception('PNR is required');
      }

      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .get();
      final data = faculty.toMap();
      data['pnr'] = pnr;
      data['password'] = password;
      data['role'] = 'faculty';
      data['isApproved'] = true;

      if (snap.docs.isEmpty) {
        await _db.collection('users').doc(pnr).set(data);
        return;
      }

      // Update all matching docs to avoid duplicates for the same PNR.
      for (final doc in snap.docs) {
        await doc.reference.update(data);
      }
    } catch (e) {
      throw Exception("Error creating faculty: $e");
    }
  }

  Stream<List<AppUser>> getPendingStudents() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUser.fromMap(d.data()))
              .toList(),
        );
  }

  Stream<List<AppUser>> getPendingFaculty() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'faculty')
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUser.fromMap(d.data()))
              .toList(),
        );
  }

  Future<void> approveUser(String pnr) async {
    try {
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .get();
      if (snap.docs.isEmpty) return;
      for (final doc in snap.docs) {
        await doc.reference.update({'isApproved': true});
      }
    } catch (e) {
      throw Exception("Error approving student: $e");
    }
  }

  Future<void> approveStudent(String pnr) async {
    await approveUser(pnr);
  }

  Stream<List<AppUser>> getApprovedFaculty() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'faculty')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUser.fromMap(d.data()))
              .toList(),
        );
  }

  Future<void> assignSubjectToFaculty({
    required String branch,
    required String division,
    required int year,
    required int semesterNumber,
    required String facultyPnr,
    required String facultyName,
    required String subject,
  }) async {
    try {
      final doc = _db.collection('subject_assignments').doc();
      final className = '${branch.trim()}-${division.trim()}';
      await doc.set({
        'subject': subject.trim(),
        'facultyPnr': facultyPnr.trim(),
        'facultyName': facultyName.trim(),
        'branch': branch.trim(),
        'division': division.trim(),
        'year': year,
        'semesterNumber': semesterNumber,
        'className': className,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Error assigning subject: $e');
    }
  }

  Stream<List<ClassCoordinatorAssignment>> watchClassCoordinators() {
    return _db.collection('class_coordinators').snapshots().map((snap) {
      return snap.docs
          .map(
            (d) => ClassCoordinatorAssignment.fromMap(
              d.id,
              d.data(),
            ),
          )
          .toList();
    });
  }

  Stream<List<ClassCoordinatorAssignment>>
  watchCoordinatorAssignmentsForFaculty(String facultyPnr) {
    return _db
        .collection('class_coordinators')
        .where('facultyPnr', isEqualTo: facultyPnr.trim())
        .snapshots()
        .map((snap) {
          return snap.docs
              .map(
                (d) => ClassCoordinatorAssignment.fromMap(
                  d.id,
                  d.data(),
                ),
              )
              .toList();
        });
  }

  Future<List<ClassCoordinatorAssignment>> getCoordinatorAssignmentsForFaculty(
    String facultyPnr,
  ) async {
    try {
      final snap = await _db
          .collection('class_coordinators')
          .where('facultyPnr', isEqualTo: facultyPnr.trim())
          .get();
      return snap.docs
          .map(
            (d) => ClassCoordinatorAssignment.fromMap(
              d.id,
              d.data(),
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Error loading coordinator assignments: $e');
    }
  }

  Future<void> assignClassCoordinator({
    required String facultyPnr,
    required String facultyName,
    required String branch,
    required int year,
    required int semester,
    required String division,
  }) async {
    try {
      final doc = _db.collection('class_coordinators').doc();
      final className = '${branch.trim()}-${division.trim()}';
      await doc.set({
        'facultyPnr': facultyPnr.trim(),
        'facultyName': facultyName.trim(),
        'branch': branch.trim(),
        'year': year,
        'semester': semester,
        'division': division.trim(),
        'className': className,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Error assigning class coordinator: $e');
    }
  }

  Future<ClassCoordinatorAssignment?> getCoordinatorAssignmentForClass({
    required String className,
    required String branch,
    required int year,
    required int semester,
    required String division,
  }) async {
    try {
      final query = await _db
          .collection('class_coordinators')
          .where('className', isEqualTo: className.trim())
          .where('branch', isEqualTo: branch.trim())
          .where('year', isEqualTo: year)
          .where('semester', isEqualTo: semester)
          .where('division', isEqualTo: division.trim())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return ClassCoordinatorAssignment.fromMap(
        query.docs.first.id,
        query.docs.first.data(),
      );
    } catch (e) {
      throw Exception('Error finding coordinator assignment: $e');
    }
  }

  Future<void> deleteClassCoordinator(String id) async {
    try {
      await _db.collection('class_coordinators').doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting coordinator assignment: $e');
    }
  }

  Future<List<AttendanceRecord>> getAttendanceRecordsForClass({
    required String branch,
    required int year,
    required int semesterNumber,
    required String className,
    String? batchKey,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      Query query = _db
          .collection('attendance')
          .where('branch', isEqualTo: branch.trim())
          .where('year', isEqualTo: year)
          .where('semesterNumber', isEqualTo: semesterNumber)
          .where('className', isEqualTo: className.trim());

      if (batchKey != null && batchKey.trim().isNotEmpty) {
        query = query.where('batchKey', isEqualTo: batchKey.trim());
      }
      if (fromDate != null) {
        query = query.where(
          'dateKey',
          isGreaterThanOrEqualTo: _dateKeyFromDate(fromDate),
        );
      }
      if (toDate != null) {
        query = query.where(
          'dateKey',
          isLessThanOrEqualTo: _dateKeyFromDate(toDate),
        );
      }

      final snap = await query.get();
      return snap.docs
          .map(
            (d) => AttendanceRecord.fromMap(
              d.id,
              d.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Error fetching attendance records: $e');
    }
  }

  Stream<List<SubjectAssignment>> watchAssignedSubjectsForFaculty(
    String facultyPnr,
  ) {
    return _db
        .collection('subject_assignments')
        .where('facultyPnr', isEqualTo: facultyPnr.trim())
        .snapshots()
        .map((snap) {
          return snap.docs
              .map(
                (d) => SubjectAssignment.fromMap(
                  d.id,
                  d.data(),
                ),
              )
              .toList();
        });
  }

  Future<List<SubjectAssignment>> getAssignedSubjectsForFaculty(
    String facultyPnr,
  ) async {
    final snap = await _db
        .collection('subject_assignments')
        .where('facultyPnr', isEqualTo: facultyPnr.trim())
        .get();
    return snap.docs
        .map(
          (d) =>
              SubjectAssignment.fromMap(d.id, d.data()),
        )
        .toList();
  }

  Stream<List<SubjectAssignment>> watchSubjectAssignments() {
    return _db.collection('subject_assignments').snapshots().map((snap) {
      return snap.docs
          .map(
            (d) => SubjectAssignment.fromMap(
              d.id,
              d.data(),
            ),
          )
          .toList();
    });
  }

  Future<void> deleteSubjectAssignment(String id) async {
    try {
      await _db.collection('subject_assignments').doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting subject assignment: $e');
    }
  }

  Future<void> rejectUser(String pnr) async {
    try {
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .where('isApproved', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return;

      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception("Error rejecting user: $e");
    }
  }

  // Get students for a specific class
  Future<List<AppUser>> getStudentsByClass(
    String className, {
    int? semester,
    String? branch,
    String? year,
    String? batch,
  }) async {
    try {
      Query query = _db
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('isApproved', isEqualTo: true);

      if (className.isNotEmpty) {
        query = query.where('className', isEqualTo: className);
      }
      if (semester != null) {
        query = query.where('semester', isEqualTo: semester);
      }
      if (branch != null && branch.isNotEmpty) {
        query = query.where('branch', isEqualTo: branch);
      }
      if (year != null && year.isNotEmpty) {
        query = query.where('year', isEqualTo: year);
      }
      if (batch != null && batch.isNotEmpty) {
        query = query.where('batch', isEqualTo: batch);
      }

      final snap = await query.get();
      return snap.docs
          .map((d) => AppUser.fromMap(d.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception("Error fetching students: $e");
    }
  }

  Future<int> sendNotificationToStudentsByFilter({
    required String title,
    required String body,
    required String className,
    String? branch,
    String? year,
    int? semester,
    String? batch,
  }) async {
    final students = await getStudentsByClass(
      className,
      branch: branch,
      year: year,
      semester: semester,
      batch: batch,
    );

    if (students.isEmpty) return 0;

    final now = DateTime.now();
    const chunkSize = 450; // Firestore batch limit is 500 ops

    for (var i = 0; i < students.length; i += chunkSize) {
      final chunk = students.skip(i).take(chunkSize);
      final batchWrite = _db.batch();
      for (final s in chunk) {
        final ref = _db.collection('notifications').doc();
        batchWrite.set(ref, {
          'pnr': s.pnr,
          'title': title,
          'body': body,
          'timestamp': now.toIso8601String(),
          'isRead': false,
        });
      }
      await batchWrite.commit();
    }

    return students.length;
  }

  // --- ISE Marks ---

  Stream<List<IseMark>> watchIseMarksForCourse(String courseKey) {
    return _db
        .collection('ise_marks')
        .where('courseKey', isEqualTo: courseKey.trim())
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) => IseMark.fromMap(d.id, d.data())).toList();
        });
  }

  Stream<List<IseMark>> watchIseMarksForStudent(String studentPnr) {
    return _db
        .collection('ise_marks')
        .where('studentPnr', isEqualTo: studentPnr.trim())
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) => IseMark.fromMap(d.id, d.data())).toList();
        });
  }

  Future<void> upsertIseMarks({
    required String courseKey,
    required String subject,
    required String className,
    required int semesterNumber,
    required String updatedByPnr,
    required String updatedByName,
    required Map<String, ({int? ise1, int? ise2, int? ise3})>
    scoresByStudentPnr,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final entries = scoresByStudentPnr.entries.toList();
      const chunkSize = 450;

      for (var i = 0; i < entries.length; i += chunkSize) {
        final batch = _db.batch();
        final chunk = entries.skip(i).take(chunkSize);
        for (final e in chunk) {
          final studentPnr = e.key.trim();
          final scores = e.value;
          final docId = buildIseDocId(
            courseKey: courseKey,
            studentPnr: studentPnr,
          );
          final ref = _db.collection('ise_marks').doc(docId);

          batch.set(ref, {
            'courseKey': courseKey.trim(),
            'studentPnr': studentPnr,
            'subject': subject.trim(),
            'className': className.trim(),
            'semesterNumber': semesterNumber,
            'updatedByPnr': updatedByPnr.trim(),
            'updatedByName': updatedByName.trim(),
            'updatedAt': now,
            'ise1': scores.ise1 ?? FieldValue.delete(),
            'ise2': scores.ise2 ?? FieldValue.delete(),
            'ise3': scores.ise3 ?? FieldValue.delete(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Error saving ISE marks: $e');
    }
  }

  // --- Model Answer Papers (Drive link + metadata) ---

  Future<void> upsertModelAnswerPaper({
    required String courseCode,
    required String department,
    required String className,
    required DateTime date,
    required String testNo, // I/II/III
    required String fileName,
    required String fileUrl,
    required String uploadedByPnr,
    required String uploadedByName,
  }) async {
    try {
      final dateKey = dateKeyFromDate(date);
      final dateDisplay = dateDisplayDdMmYyyy(date);
      final key = buildModelAnswerKey(
        courseCode: courseCode,
        department: department,
        className: className,
        dateKey: dateKey,
        testNo: testNo,
      );
      final docId = buildModelAnswerDocId(key);

      await _db.collection('model_answer_papers').doc(docId).set({
        'key': key,
        'courseCode': courseCode.trim(),
        'department': department.trim(),
        'className': className.trim(),
        'dateKey': dateKey,
        'dateDisplay': dateDisplay,
        'testNo': testNo.trim(),
        'fileName': fileName.trim(),
        'fileUrl': fileUrl.trim(),
        'uploadedByPnr': uploadedByPnr.trim(),
        'uploadedByName': uploadedByName.trim(),
        'uploadedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error saving model answer paper: $e');
    }
  }

  Future<ModelAnswerPaper?> getModelAnswerPaperByScanJsonFields({
    required String courseCode,
    required String department,
    required String className,
    required String dateDdMmYyyy,
    required String testNo,
  }) async {
    try {
      final dateKey = tryParseDdMmYyyyToDateKey(dateDdMmYyyy);
      if (dateKey == null) return null;

      final key = buildModelAnswerKey(
        courseCode: courseCode,
        department: department,
        className: className,
        dateKey: dateKey,
        testNo: testNo,
      );
      final docId = buildModelAnswerDocId(key);
      final snap = await _db.collection('model_answer_papers').doc(docId).get();
      if (!snap.exists) return null;
      return ModelAnswerPaper.fromMap(
        snap.id,
        snap.data() as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Error fetching model answer paper: $e');
    }
  }

  Stream<List<ModelAnswerPaper>> watchModelAnswerPapersForFaculty(
    String facultyPnr,
  ) {
    return _db
        .collection('model_answer_papers')
        .where('uploadedByPnr', isEqualTo: facultyPnr.trim())
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => ModelAnswerPaper.fromMap(d.id, d.data()))
              .toList();
        });
  }

  Future<void> deleteModelAnswerPaper(String id) async {
    try {
      await _db.collection('model_answer_papers').doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting model answer paper: $e');
    }
  }

  // --- Timetable Management ---

  Future<void> addTimetableEntry(TimetableEntry entry) async {
    try {
      await _db.collection('timetable').add(entry.toMap());
    } catch (e) {
      throw Exception("Error adding timetable: $e");
    }
  }

  Future<void> updateTimetableEntry(
    String entryId,
    TimetableEntry entry,
  ) async {
    try {
      await _db.collection('timetable').doc(entryId).update(entry.toMap());
    } catch (e) {
      throw Exception("Error updating timetable: $e");
    }
  }

  Future<void> deleteTimetableEntry(String entryId) async {
    try {
      await _db.collection('timetable').doc(entryId).delete();
    } catch (e) {
      throw Exception("Error deleting timetable: $e");
    }
  }

  Future<void> addBulkTimetableEntries(List<TimetableEntry> entries) async {
    try {
      if (entries.isEmpty) return;

      const chunkSize = 450; // Firestore batch limit is 500 ops
      for (var i = 0; i < entries.length; i += chunkSize) {
        final chunk = entries.skip(i).take(chunkSize);
        final batch = _db.batch();
        for (final entry in chunk) {
          batch.set(_db.collection('timetable').doc(), entry.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception("Error adding bulk timetable: $e");
    }
  }

  Future<int> deleteTimetableForClassSemester({
    required String branch,
    required int year,
    required int semesterNumber,
    required String className,
  }) async {
    try {
      final query = await _db
          .collection('timetable')
          .where('branch', isEqualTo: branch.trim())
          .where('year', isEqualTo: year)
          .where('semesterNumber', isEqualTo: semesterNumber)
          .where('className', isEqualTo: className.trim())
          .get();

      if (query.docs.isEmpty) return 0;

      const chunkSize = 450; // Firestore batch limit is 500 ops
      var deleted = 0;
      for (var i = 0; i < query.docs.length; i += chunkSize) {
        final chunk = query.docs.skip(i).take(chunkSize);
        final batch = _db.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
          deleted++;
        }
        await batch.commit();
      }
      return deleted;
    } catch (e) {
      throw Exception('Error deleting existing timetable: $e');
    }
  }

  // Semester window (start/end dates)
  Future<void> setSemesterWindow(
    String branch,
    int year,
    int semester,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final docId = '${branch.trim()}-$year-S$semester';
    await _db.collection('semester_windows').doc(docId).set({
      'branch': branch.trim(),
      'year': year,
      'semester': semester,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<SemesterWindow?> getSemesterWindow(
    String branch,
    int year,
    int semester,
  ) async {
    final docId = '${branch.trim()}-$year-S$semester';
    final doc = await _db.collection('semester_windows').doc(docId).get();
    if (!doc.exists) return null;
    return SemesterWindow.fromMap(doc.data() as Map<String, dynamic>);
  }

  Stream<List<TimetableEntry>> getTimetableForClass(
    String className, {
    int? semesterNumber,
    int? year,
    String? branch,
  }) {
    Query query = _db
        .collection('timetable')
        .where('className', isEqualTo: className);

    if (semesterNumber != null) {
      query = query.where('semesterNumber', isEqualTo: semesterNumber);
    }
    if (year != null) {
      query = query.where('year', isEqualTo: year);
    }
    if (branch != null) {
      query = query.where('branch', isEqualTo: branch);
    }

    return query.snapshots().map(
      (snap) => snap.docs
          .map(
            (d) =>
                TimetableEntry.fromMap(d.id, d.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Stream<List<TimetableEntry>> getTimetableForFaculty(String pnr) {
    return _db
        .collection('timetable')
        .where('facultyPnr', isEqualTo: pnr)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => TimetableEntry.fromMap(
                  d.id,
                  d.data(),
                ),
              )
              .toList(),
        );
  }

  // Get timetable for a specific semester/year/branch
  Future<List<TimetableEntry>> getTimetableBySemester(
    String branch,
    int year,
    int semesterNumber, {
    String? className,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('timetable')
          .where('branch', isEqualTo: branch)
          .where('year', isEqualTo: year)
          .where('semesterNumber', isEqualTo: semesterNumber);

      if (className != null && className.trim().isNotEmpty) {
        query = query.where('className', isEqualTo: className.trim());
      }

      final snap = await query.get();
      return snap.docs
          .map(
            (d) =>
                TimetableEntry.fromMap(d.id, d.data()),
          )
          .toList();
    } catch (e) {
      throw Exception("Error fetching timetable by semester: $e");
    }
  }

  // --- Lecture Events (Cancel / Extra Lectures) ---

  Stream<List<LectureEvent>> watchLectureEventsForClass({
    required String className,
    required String fromDateKey,
    required String toDateKey,
  }) {
    return _db
        .collection('class_lecture_events')
        .doc(className)
        .collection('events')
        .where('dateKey', isGreaterThanOrEqualTo: fromDateKey)
        .where('dateKey', isLessThanOrEqualTo: toDateKey)
        .snapshots()
        .map((snap) => snap.docs.map(LectureEvent.fromDoc).toList());
  }

  Stream<List<LectureEvent>> watchLectureEventsForFacultyOnDate({
    required String facultyPnr,
    required String dateKey,
  }) {
    return _db
        .collection('faculty_lecture_events')
        .doc(facultyPnr)
        .collection('events')
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map((snap) => snap.docs.map(LectureEvent.fromDoc).toList());
  }

  Future<void> setLectureCancelled({
    required TimetableEntry entry,
    required DateTime date,
    required bool cancelled,
  }) async {
    final dateKey = _dateKeyFromDate(date);
    final eventId = 'cancel_${dateKey}_${entry.id}';

    final classRef = _db
        .collection('class_lecture_events')
        .doc(entry.className)
        .collection('events')
        .doc(eventId);

    final facultyRef = _db
        .collection('faculty_lecture_events')
        .doc(entry.facultyPnr)
        .collection('events')
        .doc(eventId);

    if (!cancelled) {
      await classRef.delete().catchError((_) {});
      await facultyRef.delete().catchError((_) {});
      return;
    }

    final event = LectureEvent(
      id: eventId,
      type: LectureEventType.cancel,
      dateKey: dateKey,
      day: _dayNameFromWeekday(date.weekday),
      startTime: entry.startTime,
      endTime: entry.endTime,
      subject: entry.subject,
      className: entry.className,
      facultyPnr: entry.facultyPnr,
      facultyName: entry.facultyName,
      batchName: entry.batchName,
      timetableEntryId: entry.id,
      createdAt: DateTime.now(),
    );

    await classRef.set(event.toMap(), SetOptions(merge: true));
    await facultyRef.set(event.toMap(), SetOptions(merge: true));

    try {
      final students = await getStudentsByClass(
        entry.className,
        semester: entry.semesterNumber,
        branch: entry.branch,
        year: entry.year.toString(),
        batch: entry.batchName,
      );
      for (final s in students) {
        await sendNotification(
          s.pnr,
          'Lecture Cancelled',
          '${entry.subject} (${entry.startTime} - ${entry.endTime}) is OFF on $dateKey.',
        );
      }
    } catch (e) {
      debugPrint('Failed to notify students for cancellation: $e');
    }
  }

  Future<void> createExtraLecture({
    required TimetableEntry template,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final dateKey = _dateKeyFromDate(date);
    final eventId = 'extra_${dateKey}_${DateTime.now().millisecondsSinceEpoch}';

    final classRef = _db
        .collection('class_lecture_events')
        .doc(template.className)
        .collection('events')
        .doc(eventId);

    final facultyRef = _db
        .collection('faculty_lecture_events')
        .doc(template.facultyPnr)
        .collection('events')
        .doc(eventId);

    final event = LectureEvent(
      id: eventId,
      type: LectureEventType.extra,
      dateKey: dateKey,
      day: _dayNameFromWeekday(date.weekday),
      startTime: startTime,
      endTime: endTime,
      subject: template.subject,
      className: template.className,
      facultyPnr: template.facultyPnr,
      facultyName: template.facultyName,
      batchName: template.batchName,
      createdAt: DateTime.now(),
    );

    await classRef.set(event.toMap(), SetOptions(merge: true));
    await facultyRef.set(event.toMap(), SetOptions(merge: true));

    try {
      final students = await getStudentsByClass(
        template.className,
        semester: template.semesterNumber,
        branch: template.branch,
        year: template.year.toString(),
        batch: template.batchName,
      );
      for (final s in students) {
        await sendNotification(
          s.pnr,
          'Extra Lecture Scheduled',
          'Extra ${template.subject} lecture on $dateKey ($startTime - $endTime).',
        );
      }
    } catch (e) {
      debugPrint('Failed to notify students for extra lecture: $e');
    }
  }

  // --- Attendance ---

  Future<void> markAttendance(AttendanceRecord record) async {
    try {
      await _db.collection('attendance').add(record.toMap());
    } catch (e) {
      throw Exception("Error marking attendance: $e");
    }
  }

  Future<AttendanceRecord?> getTodayAttendance({
    required String subject,
    required String className,
    required int semesterNumber,
    required String branch,
    required int year,
    required String facultyPnr,
    required String batchKey,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final snap = await _db
          .collection('attendance')
          .where('dateKey', isEqualTo: dateKey)
          .where('subject', isEqualTo: subject)
          .where('className', isEqualTo: className)
          .where('semesterNumber', isEqualTo: semesterNumber)
          .where('branch', isEqualTo: branch)
          .where('year', isEqualTo: year)
          .where('facultyPnr', isEqualTo: facultyPnr)
          .where('batchKey', isEqualTo: batchKey)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return AttendanceRecord.fromMap(
        doc.id,
        doc.data(),
      );
    } catch (e) {
      throw Exception("Error fetching today's attendance: $e");
    }
  }

  Future<void> upsertTodayAttendance(AttendanceRecord record) async {
    try {
      final snap = await _db
          .collection('attendance')
          .where('dateKey', isEqualTo: record.dateKey)
          .where('subject', isEqualTo: record.subject)
          .where('className', isEqualTo: record.className)
          .where('semesterNumber', isEqualTo: record.semesterNumber)
          .where('branch', isEqualTo: record.branch)
          .where('year', isEqualTo: record.year)
          .where('facultyPnr', isEqualTo: record.facultyPnr)
          .where('batchKey', isEqualTo: record.batchKey)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        await _db.collection('attendance').add(record.toMap());
        return;
      }

      final ref = snap.docs.first.reference;
      await ref.update(record.toMap());
    } catch (e) {
      throw Exception("Error upserting today's attendance: $e");
    }
  }

  Stream<List<AttendanceRecord>> getAttendanceForStudent(String pnr) {
    return _db
        .collection('attendance')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => AttendanceRecord.fromMap(
                  d.id,
                  d.data(),
                ),
              )
              .where((record) => record.records.containsKey(pnr))
              .toList(),
        );
  }

  Future<List<AttendanceRecord>> getAttendanceForClass(
    String className,
    int semesterNumber,
    String branch, {
    DateTime? start,
    DateTime? end,
  }) async {
    final snap = await _db
        .collection('attendance')
        .where('className', isEqualTo: className)
        .where('semesterNumber', isEqualTo: semesterNumber)
        .where('branch', isEqualTo: branch)
        .get();

    final records = snap.docs
        .map(
          (d) =>
              AttendanceRecord.fromMap(d.id, d.data()),
        )
        .toList();

    if (start == null && end == null) return records;

    return records.where((r) {
      final afterStart = start == null || !r.date.isBefore(start);
      final beforeEnd = end == null || !r.date.isAfter(end);
      return afterStart && beforeEnd;
    }).toList();
  }

  Stream<List<AttendanceRecord>> watchAttendanceHistoryForFaculty(
    String facultyPnr,
  ) {
    return _db
        .collection('attendance')
        .where('facultyPnr', isEqualTo: facultyPnr.trim())
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => AttendanceRecord.fromMap(
                  d.id,
                  d.data(),
                ),
              )
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  Future<void> deleteAttendanceRecord(String id) async {
    await _db.collection('attendance').doc(id).delete();
  }

  Future<void> purgeAttendanceForSemesterIfExpired(
    String branch,
    int year,
    int semesterNumber,
    DateTime endDate,
  ) async {
    final cutoff = endDate.add(const Duration(days: 2));
    if (DateTime.now().isBefore(cutoff)) return;

    final snap = await _db
        .collection('attendance')
        .where('branch', isEqualTo: branch)
        .where('year', isEqualTo: year)
        .where('semesterNumber', isEqualTo: semesterNumber)
        .get();

    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Get attendance records for a specific subject
  Future<List<AttendanceRecord>> getAttendanceForSubject(
    String subject,
    String className,
    int semesterNumber, {
    String? branch,
    int? year,
    String? batchKey,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('attendance')
          .where('subject', isEqualTo: subject)
          .where('className', isEqualTo: className)
          .where('semesterNumber', isEqualTo: semesterNumber);

      if (branch != null && branch.trim().isNotEmpty) {
        query = query.where('branch', isEqualTo: branch.trim());
      }
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      if (batchKey != null) {
        query = query.where('batchKey', isEqualTo: batchKey);
      }

      final snap = await query.get();
      return snap.docs
          .map(
            (d) => AttendanceRecord.fromMap(
              d.id,
              d.data(),
            ),
          )
          .toList();
    } catch (e) {
      throw Exception("Error fetching attendance: $e");
    }
  }

  // Calculate attendance percentage for a student in a subject
  Future<double> getAttendancePercentage(
    String studentPnr,
    String subject,
    String className,
    int semesterNumber,
  ) async {
    try {
      final records = await getAttendanceForSubject(
        subject,
        className,
        semesterNumber,
      );
      int presentCount = 0;
      int totalCount = 0;

      for (var record in records) {
        if (record.records.containsKey(studentPnr)) {
          totalCount++;
          if (record.records[studentPnr] == 'Present') {
            presentCount++;
          }
        }
      }

      if (totalCount == 0) return 0.0;
      return (presentCount / totalCount) * 100;
    } catch (e) {
      throw Exception("Error calculating attendance percentage: $e");
    }
  }

  // Get all subjects for a student and their attendance percentages
  Future<Map<String, double>> getAllSubjectsAttendance(
    String studentPnr,
    String className,
    int semesterNumber,
  ) async {
    try {
      final snap = await _db
          .collection('attendance')
          .where('className', isEqualTo: className)
          .where('semesterNumber', isEqualTo: semesterNumber)
          .get();

      final records = snap.docs
          .map(
            (d) => AttendanceRecord.fromMap(
              d.id,
              d.data(),
            ),
          )
          .toList();

      // Group by subject
      final subjectMap = <String, List<AttendanceRecord>>{};
      for (var record in records) {
        if (record.records.containsKey(studentPnr)) {
          subjectMap.putIfAbsent(record.subject, () => []);
          subjectMap[record.subject]!.add(record);
        }
      }

      // Calculate percentages
      final result = <String, double>{};
      for (var subject in subjectMap.keys) {
        int presentCount = 0;
        int totalCount = subjectMap[subject]!.length;

        for (var record in subjectMap[subject]!) {
          if (record.records[studentPnr] == 'Present') {
            presentCount++;
          }
        }

        result[subject] = totalCount == 0
            ? 0.0
            : (presentCount / totalCount) * 100;
      }

      return result;
    } catch (e) {
      throw Exception("Error fetching all subjects attendance: $e");
    }
  }

  // Get overall attendance percentage for a student
  Future<double> getOverallAttendance(
    String studentPnr,
    String className,
    int semesterNumber,
  ) async {
    try {
      final subjectAttendance = await getAllSubjectsAttendance(
        studentPnr,
        className,
        semesterNumber,
      );
      if (subjectAttendance.isEmpty) return 0.0;

      final total = subjectAttendance.values.fold<double>(
        0,
        (acc, val) => acc + val,
      );
      return total / subjectAttendance.length;
    } catch (e) {
      throw Exception("Error calculating overall attendance: $e");
    }
  }

  // Get list of classes for a semester
  Future<List<String>> getClassesForSemester(
    String branch,
    int year,
    int semesterNumber,
  ) async {
    try {
      final snap = await _db
          .collection('timetable')
          .where('branch', isEqualTo: branch)
          .where('year', isEqualTo: year)
          .where('semesterNumber', isEqualTo: semesterNumber)
          .get();

      final classes = <String>{};
      for (var doc in snap.docs) {
        classes.add(doc['className'] ?? '');
      }
      return classes.toList();
    } catch (e) {
      throw Exception("Error fetching classes: $e");
    }
  }

  // --- Disputes ---

  Future<void> raiseDispute(Dispute dispute) async {
    try {
      await _db.collection('disputes').add(dispute.toMap());
    } catch (e) {
      throw Exception("Error raising dispute: $e");
    }
  }

  static String buildLectureKey({
    required String dateKey,
    required String subject,
    required String className,
    required String facultyPnr,
    required String batchKey,
    required String startTime,
    required String endTime,
  }) {
    return [
      dateKey.trim(),
      subject.trim(),
      className.trim(),
      facultyPnr.trim(),
      batchKey.trim(),
      startTime.trim(),
      endTime.trim(),
    ].join('|');
  }

  Future<Dispute?> getPendingDisputeForLecture({
    required String lectureKey,
    required String studentPnr,
  }) async {
    try {
      final snap = await _db
          .collection('disputes')
          .where('lectureKey', isEqualTo: lectureKey)
          .where('studentPnr', isEqualTo: studentPnr)
          .where('status', isEqualTo: 'Pending')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return Dispute.fromMap(doc.id, doc.data());
    } catch (e) {
      throw Exception("Error checking dispute: $e");
    }
  }

  Future<void> raiseDisputeForLecture({
    required String studentPnr,
    required String subject,
    required String reason,
    required DateTime lectureDate,
    required String className,
    required int semesterNumber,
    required String branch,
    required int year,
    required String facultyPnr,
    required String batchKey,
    required String lectureStartTime,
    required String lectureEndTime,
    required DateTime validFrom,
    required DateTime validTo,
  }) async {
    try {
      final now = DateTime.now();
      if (now.isBefore(validFrom) || now.isAfter(validTo)) {
        throw Exception('Dispute window is closed.');
      }

      final dateKey =
          '${lectureDate.year.toString().padLeft(4, '0')}-${lectureDate.month.toString().padLeft(2, '0')}-${lectureDate.day.toString().padLeft(2, '0')}';

      final lectureKey = buildLectureKey(
        dateKey: dateKey,
        subject: subject,
        className: className,
        facultyPnr: facultyPnr,
        batchKey: batchKey,
        startTime: lectureStartTime,
        endTime: lectureEndTime,
      );

      final existing = await getPendingDisputeForLecture(
        lectureKey: lectureKey,
        studentPnr: studentPnr,
      );
      if (existing != null) {
        throw Exception('You already raised a dispute for this lecture.');
      }

      final dispute = Dispute(
        id: '',
        studentPnr: studentPnr,
        subject: subject,
        date: lectureDate,
        reason: reason.trim(),
        status: 'Pending',
        dateKey: dateKey,
        lectureStartTime: lectureStartTime,
        lectureEndTime: lectureEndTime,
        className: className,
        semesterNumber: semesterNumber,
        branch: branch,
        year: year,
        facultyPnr: facultyPnr,
        batchKey: batchKey,
        lectureKey: lectureKey,
        validFrom: validFrom,
        validTo: validTo,
        createdAt: now,
      );

      await _db.collection('disputes').add(dispute.toMap());
    } catch (e) {
      throw Exception("Error raising dispute: $e");
    }
  }

  Stream<List<Dispute>> getDisputesForFaculty(String subject) {
    return _db
        .collection('disputes')
        .where('subject', isEqualTo: subject)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => Dispute.fromMap(d.id, d.data()),
              )
              .toList(),
        );
  }

  Stream<List<Dispute>> getActiveDisputesForFaculty(String subject) {
    return getDisputesForFaculty(subject).map((disputes) {
      final now = DateTime.now();
      return disputes.where((d) {
        final from = d.validFrom;
        final to = d.validTo;
        if (from == null || to == null) return true; // legacy disputes
        return !now.isBefore(from) && !now.isAfter(to);
      }).toList();
    });
  }

  Stream<List<Dispute>> getActiveDisputesForFacultyPnr(
    String subject,
    String facultyPnr,
  ) {
    return getActiveDisputesForFaculty(subject).map((disputes) {
      final pnr = facultyPnr.trim();
      if (pnr.isEmpty) return disputes;
      return disputes.where((d) {
        final dPnr = (d.facultyPnr ?? '').trim();
        return dPnr.isEmpty || dPnr == pnr; // allow legacy disputes
      }).toList();
    });
  }

  Future<void> resolveDispute(
    String disputeId,
    String newStatus,
    String studentPnr,
    String subject,
  ) async {
    try {
      await _db.collection('disputes').doc(disputeId).update({
        'status': newStatus,
      });
      if (newStatus == 'Approved') {
        // Prefer updating the exact lecture's attendance record, if the dispute
        // contains lecture identifiers (added in newer versions).
        final disputeDoc = await _db
            .collection('disputes')
            .doc(disputeId)
            .get();
        final disputeData = disputeDoc.data();

        if (disputeData != null &&
            disputeData['dateKey'] != null &&
            disputeData['className'] != null &&
            disputeData['semesterNumber'] != null &&
            disputeData['branch'] != null &&
            disputeData['year'] != null &&
            disputeData['facultyPnr'] != null &&
            disputeData['batchKey'] != null) {
          final snap = await _db
              .collection('attendance')
              .where('dateKey', isEqualTo: disputeData['dateKey'])
              .where('subject', isEqualTo: subject)
              .where('className', isEqualTo: disputeData['className'])
              .where('semesterNumber', isEqualTo: disputeData['semesterNumber'])
              .where('branch', isEqualTo: disputeData['branch'])
              .where('year', isEqualTo: disputeData['year'])
              .where('facultyPnr', isEqualTo: disputeData['facultyPnr'])
              .where('batchKey', isEqualTo: disputeData['batchKey'])
              .limit(1)
              .get();

          if (snap.docs.isEmpty) {
            throw Exception('Attendance is not marked yet for this lecture.');
          }

          final doc = snap.docs.first;
          final attendanceData = doc.data();
          final records = Map<String, dynamic>.from(
            attendanceData['records'] ?? {},
          );
          records[studentPnr] = 'Present';
          await doc.reference.update({'records': records});
          return;
        }

        // Legacy fallback: update the most recent attendance record for this subject.
        final snap = await _db
            .collection('attendance')
            .where('subject', isEqualTo: subject)
            .orderBy('date', descending: true)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) return;
        final doc = snap.docs.first;
        final attendanceData = doc.data();
        final records = Map<String, dynamic>.from(
          attendanceData['records'] ?? {},
        );
        records[studentPnr] = 'Present';
        await doc.reference.update({'records': records});
      }
    } catch (e) {
      throw Exception("Error resolving dispute: $e");
    }
  }

  // --- Notifications ---

  DateTime _notificationTimestamp(dynamic raw) {
    try {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  Future<void> sendNotification(String pnr, String title, String body) async {
    try {
      // Check if a similar notification was sent in the last 15 minutes to avoid flooding
      final now = DateTime.now();
      final recentSnap = await _db
          .collection('notifications')
          .where('pnr', isEqualTo: pnr)
          .where('title', isEqualTo: title)
          .limit(10)
          .get();

      if (recentSnap.docs.isNotEmpty) {
        final lastTime = recentSnap.docs
            .map((d) => _notificationTimestamp(d.data()['timestamp']))
            .fold<DateTime>(DateTime.fromMillisecondsSinceEpoch(0), (a, b) {
              return a.isAfter(b) ? a : b;
            });
        if (now.difference(lastTime).inMinutes < 15) {
          return; // Skip duplicate notification
        }
      }

      await _db.collection('notifications').add({
        'pnr': pnr,
        'title': title,
        'body': body,
        'timestamp': now.toIso8601String(),
        'isRead': false,
      });
    } catch (e) {
      throw Exception("Error sending notification: $e");
    }
  }

  Stream<List<AppNotification>> getNotifications(String pnr) {
    return _db
        .collection('notifications')
        .where('pnr', isEqualTo: pnr)
        .limit(200)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AppNotification.fromMap({'id': d.id, ...d.data()}))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _db.collection('notifications').doc(id).update({'isRead': true});
    } catch (e) {
      throw Exception("Error marking notification as read: $e");
    }
  }

  Future<void> clearNotificationsForPnr(String pnr) async {
    try {
      // Firestore batches support up to 500 ops; delete in chunks.
      while (true) {
        final snap = await _db
            .collection('notifications')
            .where('pnr', isEqualTo: pnr)
            .limit(450)
            .get();

        if (snap.docs.isEmpty) return;

        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception("Error clearing notifications: $e");
    }
  }

  // --- FCM Tokens ---

  Future<void> updateUserFcmToken(String pnr, String token) async {
    try {
      final snap = await _db
          .collection('users')
          .where('pnr', isEqualTo: pnr)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }
}
