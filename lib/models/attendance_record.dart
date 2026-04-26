class AttendanceRecord {
  final String id;
  // Day of the attendance (date-only; time is typically 00:00 local)
  final DateTime date;
  // When this attendance for the day was first saved (used for 6-hour edit window)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String subject;
  final String facultyPnr;
  final String facultyName;
  final String className;
  final String? startTime; // e.g. 10:15 AM (optional)
  final String? endTime; // e.g. 11:15 AM (optional)
  final int semesterNumber;
  final int year;
  final String branch;
  final String? batch; // Added for batches
  // Normalized batch key for reliable querying ('' for theory / no batch)
  final String batchKey;
  // Key: Student PNR, Value: Status ('Present' or 'Absent')
  final Map<String, String> records;

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.createdAt,
    this.updatedAt,
    required this.subject,
    required this.facultyPnr,
    required this.facultyName,
    required this.className,
    this.startTime,
    this.endTime,
    required this.semesterNumber,
    required this.year,
    required this.branch,
    this.batch,
    String? batchKey,
    required this.records,
  }) : batchKey = (batchKey ?? batch ?? '').trim();

  static String _two(int v) => v.toString().padLeft(2, '0');

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) {
    final date =
        data['date'] != null ? DateTime.parse(data['date']) : DateTime.now();
    final createdAt = data['createdAt'] != null
        ? DateTime.parse(data['createdAt'])
        : date;
    final updatedAt =
        data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null;

    final dynamicBatch = data['batch'];
    final dynamicBatchKey = data['batchKey'];
    final parsedBatch = dynamicBatch?.toString();
    final parsedBatchKey = dynamicBatchKey?.toString() ?? '';
    final effectiveBatchKey = (parsedBatchKey.isNotEmpty
        ? parsedBatchKey
        : (parsedBatch ?? '')).trim();
    final effectiveBatch =
        effectiveBatchKey.isEmpty ? null : (parsedBatch ?? effectiveBatchKey);

    return AttendanceRecord(
      id: id,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
      subject: data['subject'] ?? '',
      facultyPnr: data['facultyPnr'] ?? '',
      facultyName: data['facultyName'] ?? '',
      className: data['class'] ?? data['className'] ?? '',
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
      semesterNumber: data['semesterNumber'] ?? 1,
      year: data['year'] ?? 1,
      branch: data['branch'] ?? '',
      batch: effectiveBatch,
      batchKey: effectiveBatchKey,
      records: Map<String, String>.from(data['records'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'dateKey': dateKey,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'subject': subject,
      'facultyPnr': facultyPnr,
      'facultyName': facultyName,
      'class': className,
      'className': className,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'semesterNumber': semesterNumber,
      'year': year,
      'branch': branch,
      if (batch != null) 'batch': batch,
      'batchKey': batchKey,
      'records': records,
    };
  }

  // Calculate attendance percentage for a specific student
  double getStudentAttendancePercentage(String studentPnr, List<AttendanceRecord> allRecordsForSubject) {
    int totalClasses = 0;
    int presentClasses = 0;

    for (var record in allRecordsForSubject) {
      if (record.records.containsKey(studentPnr)) {
        totalClasses++;
        if (record.records[studentPnr] == 'Present') {
          presentClasses++;
        }
      }
    }

    if (totalClasses == 0) return 0.0;
    return (presentClasses / totalClasses) * 100;
  }
}
