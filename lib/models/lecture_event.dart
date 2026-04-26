import 'package:cloud_firestore/cloud_firestore.dart';

enum LectureEventType { cancel, extra }

LectureEventType _typeFromString(String raw) {
  switch (raw) {
    case 'cancel':
      return LectureEventType.cancel;
    case 'extra':
      return LectureEventType.extra;
    default:
      return LectureEventType.extra;
  }
}

String _typeToString(LectureEventType type) {
  switch (type) {
    case LectureEventType.cancel:
      return 'cancel';
    case LectureEventType.extra:
      return 'extra';
  }
}

class LectureEvent {
  final String id;
  final LectureEventType type;
  final String dateKey; // yyyy-MM-dd
  final String day; // Monday, Tuesday...
  final String startTime; // hh:mm a
  final String endTime; // hh:mm a
  final String subject;
  final String className;
  final String facultyPnr;
  final String facultyName;
  final String? batchName;
  final String? timetableEntryId; // for cancel events
  final DateTime createdAt;

  LectureEvent({
    required this.id,
    required this.type,
    required this.dateKey,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.className,
    required this.facultyPnr,
    required this.facultyName,
    this.batchName,
    this.timetableEntryId,
    required this.createdAt,
  });

  factory LectureEvent.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return LectureEvent(
      id: doc.id,
      type: _typeFromString((data['type'] ?? '').toString()),
      dateKey: (data['dateKey'] ?? '').toString(),
      day: (data['day'] ?? '').toString(),
      startTime: (data['startTime'] ?? '').toString(),
      endTime: (data['endTime'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      className: (data['className'] ?? data['class'] ?? '').toString(),
      facultyPnr: (data['facultyPnr'] ?? '').toString(),
      facultyName: (data['facultyName'] ?? '').toString(),
      batchName: data['batchName']?.toString(),
      timetableEntryId: data['timetableEntryId']?.toString(),
      createdAt: data['createdAt'] is String
          ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
          : data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': _typeToString(type),
      'dateKey': dateKey,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'className': className,
      'class': className,
      'facultyPnr': facultyPnr,
      'facultyName': facultyName,
      if (batchName != null) 'batchName': batchName,
      if (timetableEntryId != null) 'timetableEntryId': timetableEntryId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

