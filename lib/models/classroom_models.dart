class ClassroomRoom {
  final String id;
  final String title;
  final String department; // branch e.g. CSE
  final int year; // 1..4
  final String division; // A/B/...
  final String code; // join code
  final bool isDeleted;
  final String createdByPnr;
  final String createdByName;
  final String? createdByEmail;
  final DateTime createdAt;
  final DateTime? deletedAt;

  ClassroomRoom({
    required this.id,
    required this.title,
    required this.department,
    required this.year,
    required this.division,
    required this.code,
    this.isDeleted = false,
    required this.createdByPnr,
    required this.createdByName,
    required this.createdAt,
    this.createdByEmail,
    this.deletedAt,
  });

  factory ClassroomRoom.fromMap(String id, Map<String, dynamic> data) {
    return ClassroomRoom(
      id: id,
      title: (data['title'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      year: data['year'] is int
          ? data['year'] as int
          : int.tryParse((data['year'] ?? '').toString()) ?? 1,
      division: (data['division'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      isDeleted: (data['isDeleted'] == true),
      createdByPnr: (data['createdByPnr'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdByEmail: data['createdByEmail']?.toString(),
      createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      deletedAt: data['deletedAt'] != null
          ? DateTime.tryParse(data['deletedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'department': department,
      'year': year,
      'division': division,
      'code': code,
      'isDeleted': isDeleted,
      'createdByPnr': createdByPnr,
      'createdByName': createdByName,
      if (createdByEmail != null) 'createdByEmail': createdByEmail,
      'createdAt': createdAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }
}

class ClassroomAssignment {
  final String id;
  final String classroomId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? dueAt;
  final String? materialFileName;
  final String? materialUrl;

  ClassroomAssignment({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.dueAt,
    this.materialFileName,
    this.materialUrl,
  });

  factory ClassroomAssignment.fromMap(
    String id,
    String classroomId,
    Map<String, dynamic> data,
  ) {
    return ClassroomAssignment(
      id: id,
      classroomId: classroomId,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      dueAt: data['dueAt'] != null
          ? DateTime.tryParse(data['dueAt'].toString())
          : null,
      materialFileName: data['materialFileName']?.toString(),
      materialUrl: data['materialUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
      if (materialFileName != null) 'materialFileName': materialFileName,
      if (materialUrl != null) 'materialUrl': materialUrl,
    };
  }
}

class ClassroomSubmission {
  final String id; // studentPnr
  final String assignmentId;
  final String studentPnr;
  final String studentName;
  final DateTime updatedAt;
  final String? note;
  final String? fileName;
  final String? fileUrl;
  final String? storagePath;

  ClassroomSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentPnr,
    required this.studentName,
    required this.updatedAt,
    this.note,
    this.fileName,
    this.fileUrl,
    this.storagePath,
  });

  factory ClassroomSubmission.fromMap(
    String id,
    String assignmentId,
    Map<String, dynamic> data,
  ) {
    return ClassroomSubmission(
      id: id,
      assignmentId: assignmentId,
      studentPnr: (data['studentPnr'] ?? id).toString(),
      studentName: (data['studentName'] ?? '').toString(),
      updatedAt: DateTime.tryParse((data['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      note: data['note']?.toString(),
      fileName: data['fileName']?.toString(),
      fileUrl: data['fileUrl']?.toString(),
      storagePath: data['storagePath']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentPnr': studentPnr,
      'studentName': studentName,
      'updatedAt': updatedAt.toIso8601String(),
      if (note != null) 'note': note,
      if (fileName != null) 'fileName': fileName,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (storagePath != null) 'storagePath': storagePath,
    };
  }
}

class ClassroomAnnouncement {
  final String id;
  final String classroomId;
  final String title;
  final String message;
  final String createdByPnr;
  final String createdByName;
  final DateTime createdAt;

  ClassroomAnnouncement({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.message,
    required this.createdByPnr,
    required this.createdByName,
    required this.createdAt,
  });

  factory ClassroomAnnouncement.fromMap(
    String id,
    String classroomId,
    Map<String, dynamic> data,
  ) {
    return ClassroomAnnouncement(
      id: id,
      classroomId: classroomId,
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      createdByPnr: (data['createdByPnr'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ClassroomMember {
  final String id; // studentPnr
  final String studentPnr;
  final String studentName;
  final String? rollNo;
  final int? rollNoInt;
  final DateTime joinedAt;

  ClassroomMember({
    required this.id,
    required this.studentPnr,
    required this.studentName,
    required this.joinedAt,
    this.rollNo,
    this.rollNoInt,
  });

  factory ClassroomMember.fromMap(String id, Map<String, dynamic> data) {
    final rollNo = data['rollNo']?.toString();
    final rollNoInt = data['rollNoInt'] is int
        ? data['rollNoInt'] as int
        : int.tryParse(data['rollNoInt']?.toString() ?? '') ??
            int.tryParse(rollNo?.toString() ?? '');
    return ClassroomMember(
      id: id,
      studentPnr: (data['studentPnr'] ?? id).toString(),
      studentName: (data['studentName'] ?? '').toString(),
      rollNo: rollNo,
      rollNoInt: rollNoInt,
      joinedAt: DateTime.tryParse((data['joinedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ClassroomNote {
  final String id;
  final String classroomId;
  final String title;
  final String content;
  final String? fileName;
  final String? fileUrl;
  final String createdByPnr;
  final String createdByName;
  final DateTime createdAt;

  ClassroomNote({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.content,
    required this.createdByPnr,
    required this.createdByName,
    required this.createdAt,
    this.fileName,
    this.fileUrl,
  });

  factory ClassroomNote.fromMap(
    String id,
    String classroomId,
    Map<String, dynamic> data,
  ) {
    return ClassroomNote(
      id: id,
      classroomId: classroomId,
      title: (data['title'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      fileName: data['fileName']?.toString(),
      fileUrl: data['fileUrl']?.toString(),
      createdByPnr: (data['createdByPnr'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
