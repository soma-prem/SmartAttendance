import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/classroom_models.dart';
import '../models/user_model.dart';

class ClassroomService {
  ClassroomService({
    FirebaseFirestore? firestore,
  }) : _db = firestore;

  FirebaseFirestore? _db;

  FirebaseFirestore get _firestore => _db ??= FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _classrooms =>
      _firestore.collection('classrooms');

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final snap =
          await _classrooms.where('code', isEqualTo: code).limit(1).get();
      if (snap.docs.isEmpty) return code;
    }
    // last resort (still very low collision probability)
    return _generateCode();
  }

  Stream<List<ClassroomRoom>> watchClassroomsForStudent({
    required String department,
    required int year,
    required String division,
  }) {
    return _classrooms
        .where('department', isEqualTo: department.trim())
        .where('year', isEqualTo: year)
        .where('division', isEqualTo: division.trim())
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ClassroomRoom.fromMap(d.id, d.data()))
              .toList();
          final filtered = list.where((r) => !r.isDeleted).toList();
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return filtered;
        });
  }

  Stream<List<ClassroomRoom>> watchClassroomsForFaculty({
    required String facultyPnr,
  }) {
    return _classrooms
        .where('createdByPnr', isEqualTo: facultyPnr.trim())
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ClassroomRoom.fromMap(d.id, d.data()))
              .toList();
          final filtered = list.where((r) => !r.isDeleted).toList();
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return filtered;
        });
  }

  Stream<ClassroomRoom?> watchClassroom(String classroomId) {
    return _classrooms.doc(classroomId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ClassroomRoom.fromMap(
        snap.id,
        snap.data() as Map<String, dynamic>,
      );
    });
  }

  Stream<List<Map<String, dynamic>>> watchMyMemberships(String studentPnr) {
    return _firestore
        .collection('classroom_memberships')
        .doc(studentPnr.trim())
        .collection('rooms')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<ClassroomRoom> createClassroom({
    required String title,
    required String department,
    required int year,
    required String division,
    required AppUser faculty,
    String? facultyEmail,
  }) async {
    final now = DateTime.now();
    final code = await _generateUniqueCode();

    final doc = await _classrooms.add({
      'title': title.trim(),
      'department': department.trim(),
      'year': year,
      'division': division.trim(),
      'code': code,
      'isDeleted': false,
      'createdByPnr': faculty.pnr,
      'createdByName': faculty.name,
      'createdByEmail': facultyEmail,
      'createdAt': now.toIso8601String(),
    });

    return ClassroomRoom(
      id: doc.id,
      title: title.trim(),
      department: department.trim(),
      year: year,
      division: division.trim(),
      code: code,
      isDeleted: false,
      createdByPnr: faculty.pnr,
      createdByName: faculty.name,
      createdByEmail: facultyEmail,
      createdAt: now,
    );
  }

  Future<void> softDeleteClassroom(String classroomId) async {
    await _classrooms.doc(classroomId).set(
      {
        'isDeleted': true,
        'deletedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<ClassroomRoom?> findClassroomByCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final snap =
        await _classrooms.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final room = ClassroomRoom.fromMap(doc.id, doc.data());
    if (room.isDeleted) return null;
    return room;
  }

  Future<void> joinClassroomByCode({
    required String code,
    required AppUser student,
  }) async {
    final room = await findClassroomByCode(code);
    if (room == null) {
      throw Exception('Classroom code not found.');
    }

    final studentBranch = student.branch?.trim() ?? '';
    final studentDivision = student.division?.trim() ?? '';
    final studentYear = int.tryParse((student.year ?? '').trim());

    if (studentBranch.isEmpty || studentDivision.isEmpty || studentYear == null) {
      throw Exception('Your profile is missing Branch/Year/Division.');
    }

    if (studentBranch != room.department ||
        studentDivision != room.division ||
        studentYear != room.year) {
      throw Exception('This classroom does not match your Branch/Year/Division.');
    }

    final now = DateTime.now();
    final memberRef =
        _classrooms.doc(room.id).collection('members').doc(student.pnr.trim());
    await memberRef.set({
      'studentPnr': student.pnr.trim(),
      'studentName': student.name.trim(),
      'rollNo': student.rollNo?.toString().trim(),
      'rollNoInt': int.tryParse((student.rollNo ?? '').toString().trim()),
      'joinedAt': now.toIso8601String(),
    }, SetOptions(merge: true));

    final membershipRef = _firestore
        .collection('classroom_memberships')
        .doc(student.pnr.trim())
        .collection('rooms')
        .doc(room.id);
    await membershipRef.set({
      'classroomId': room.id,
      'joinedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Stream<List<ClassroomAssignment>> watchAssignments(String classroomId) {
    return _classrooms
        .doc(classroomId)
        .collection('assignments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => ClassroomAssignment.fromMap(
                  d.id,
                  classroomId,
                  d.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> createAssignment({
    required String classroomId,
    required String title,
    required String description,
    DateTime? dueAt,
    String? materialFileName,
    String? materialUrl,
  }) async {
    await _classrooms.doc(classroomId).collection('assignments').add({
      'title': title.trim(),
      'description': description.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
      if (materialFileName != null && materialFileName.trim().isNotEmpty)
        'materialFileName': materialFileName.trim(),
      if (materialUrl != null && materialUrl.trim().isNotEmpty)
        'materialUrl': materialUrl.trim(),
    });
  }

  Future<void> deleteAssignment({
    required String classroomId,
    required String assignmentId,
  }) async {
    final assignmentRef =
        _classrooms.doc(classroomId).collection('assignments').doc(assignmentId);

    // Delete submissions (best-effort) then delete the assignment doc.
    final subs = await assignmentRef.collection('submissions').get();
    for (final d in subs.docs) {
      await d.reference.delete();
    }

    await assignmentRef.delete();
  }

  Stream<ClassroomSubmission?> watchMySubmission({
    required String classroomId,
    required String assignmentId,
    required String studentPnr,
  }) {
    final ref = _classrooms
        .doc(classroomId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .doc(studentPnr.trim());
    return ref.snapshots().map((snap) {
      if (!snap.exists) return null;
      return ClassroomSubmission.fromMap(
        snap.id,
        assignmentId,
        snap.data() as Map<String, dynamic>,
      );
    });
  }

  Stream<List<ClassroomSubmission>> watchSubmissions({
    required String classroomId,
    required String assignmentId,
  }) {
    return _classrooms
        .doc(classroomId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map(
            (d) => ClassroomSubmission.fromMap(
              d.id,
              assignmentId,
              d.data(),
            ),
          )
          .toList();
    });
  }

  Future<void> upsertSubmission({
    required String classroomId,
    required String assignmentId,
    required String studentPnr,
    required String studentName,
    required String fileName,
    required String fileUrl,
    String? note,
  }) async {
    final safeStudent = studentPnr.trim();

    final submissionRef = _classrooms
        .doc(classroomId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .doc(safeStudent);

    await submissionRef.set({
      'studentPnr': safeStudent,
      'studentName': studentName.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
      'note': note?.trim(),
      'fileName': fileName.trim(),
      'fileUrl': fileUrl.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> unsubmit({
    required String classroomId,
    required String assignmentId,
    required String studentPnr,
  }) async {
    final ref = _classrooms
        .doc(classroomId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .doc(studentPnr.trim());
    await ref.delete();
  }

  Stream<List<ClassroomAnnouncement>> watchAnnouncements(String classroomId) {
    return _classrooms
        .doc(classroomId)
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map(
            (d) => ClassroomAnnouncement.fromMap(
              d.id,
              classroomId,
              d.data(),
            ),
          )
          .toList();
    });
  }

  Future<void> createAnnouncement({
    required String classroomId,
    required String title,
    required String message,
    required AppUser createdBy,
  }) async {
    await _classrooms.doc(classroomId).collection('announcements').add({
      'title': title.trim(),
      'message': message.trim(),
      'createdByPnr': createdBy.pnr,
      'createdByName': createdBy.name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteAnnouncement({
    required String classroomId,
    required String announcementId,
  }) async {
    await _classrooms
        .doc(classroomId)
        .collection('announcements')
        .doc(announcementId)
        .delete();
  }

  Stream<List<ClassroomMember>> watchMembers(String classroomId) {
    return _classrooms
        .doc(classroomId)
        .collection('members')
        .orderBy('rollNoInt')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => ClassroomMember.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Stream<List<ClassroomNote>> watchNotes(String classroomId) {
    return _classrooms
        .doc(classroomId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => ClassroomNote.fromMap(d.id, classroomId, d.data()))
          .toList();
    });
  }

  Future<void> createNote({
    required String classroomId,
    required String title,
    required String content,
    required AppUser createdBy,
    String? fileName,
    String? fileUrl,
  }) async {
    await _classrooms.doc(classroomId).collection('notes').add({
      'title': title.trim(),
      'content': content.trim(),
      'createdByPnr': createdBy.pnr,
      'createdByName': createdBy.name,
      'createdAt': DateTime.now().toIso8601String(),
      if (fileName != null && fileName.trim().isNotEmpty)
        'fileName': fileName.trim(),
      if (fileUrl != null && fileUrl.trim().isNotEmpty)
        'fileUrl': fileUrl.trim(),
    });
  }

  Future<void> deleteNote({
    required String classroomId,
    required String noteId,
  }) async {
    await _classrooms.doc(classroomId).collection('notes').doc(noteId).delete();
  }
}
