import 'package:cloud_firestore/cloud_firestore.dart';

class ClassCoordinatorAssignment {
  final String id;
  final String facultyPnr;
  final String facultyName;
  final String branch;
  final int year;
  final int semester;
  final String division;
  final String className;
  final DateTime createdAt;

  ClassCoordinatorAssignment({
    required this.id,
    required this.facultyPnr,
    required this.facultyName,
    required this.branch,
    required this.year,
    required this.semester,
    required this.division,
    required this.className,
    required this.createdAt,
  });

  static int _parseInt(dynamic raw, {required int fallback}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
    return fallback;
  }

  static DateTime _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw.trim()) ?? DateTime.now();
    return DateTime.now();
  }

  factory ClassCoordinatorAssignment.fromMap(String id, Map<String, dynamic> data) {
    return ClassCoordinatorAssignment(
      id: id,
      facultyPnr: (data['facultyPnr'] ?? '').toString(),
      facultyName: (data['facultyName'] ?? '').toString(),
      branch: (data['branch'] ?? '').toString(),
      year: _parseInt(data['year'], fallback: 1),
      semester: _parseInt(data['semester'], fallback: 1),
      division: (data['division'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facultyPnr': facultyPnr.trim(),
      'facultyName': facultyName.trim(),
      'branch': branch.trim(),
      'year': year,
      'semester': semester,
      'division': division.trim(),
      'className': className.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
