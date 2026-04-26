class Dispute {
  final String id;
  final String studentPnr;
  final String subject;
  final DateTime date;
  final String reason;
  final String status; // 'Pending', 'Approved', 'Rejected'
  // Lecture context (optional for backward compatibility)
  final String? dateKey; // yyyy-MM-dd
  final String? lectureStartTime; // e.g. 10:15 AM
  final String? lectureEndTime; // e.g. 11:15 AM
  final String? className;
  final int? semesterNumber;
  final String? branch;
  final int? year;
  final String? facultyPnr;
  final String? batchKey;
  final String? lectureKey; // unique key for a lecture slot
  // Dispute window (optional)
  final DateTime? validFrom;
  final DateTime? validTo;
  final DateTime? createdAt;

  Dispute({
    required this.id,
    required this.studentPnr,
    required this.subject,
    required this.date,
    required this.reason,
    required this.status,
    this.dateKey,
    this.lectureStartTime,
    this.lectureEndTime,
    this.className,
    this.semesterNumber,
    this.branch,
    this.year,
    this.facultyPnr,
    this.batchKey,
    this.lectureKey,
    this.validFrom,
    this.validTo,
    this.createdAt,
  });

  factory Dispute.fromMap(String id, Map<String, dynamic> data) {
    return Dispute(
      id: id,
      studentPnr: data['studentPnr'] ?? '',
      subject: data['subject'] ?? '',
      date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'Pending',
      dateKey: data['dateKey']?.toString(),
      lectureStartTime: data['lectureStartTime']?.toString(),
      lectureEndTime: data['lectureEndTime']?.toString(),
      className: data['className']?.toString(),
      semesterNumber: data['semesterNumber'] is int
          ? data['semesterNumber'] as int
          : int.tryParse(data['semesterNumber']?.toString() ?? ''),
      branch: data['branch']?.toString(),
      year: data['year'] is int
          ? data['year'] as int
          : int.tryParse(data['year']?.toString() ?? ''),
      facultyPnr: data['facultyPnr']?.toString(),
      batchKey: data['batchKey']?.toString(),
      lectureKey: data['lectureKey']?.toString(),
      validFrom: data['validFrom'] != null
          ? DateTime.tryParse(data['validFrom'].toString())
          : null,
      validTo: data['validTo'] != null
          ? DateTime.tryParse(data['validTo'].toString())
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentPnr': studentPnr,
      'subject': subject,
      'date': date.toIso8601String(),
      'reason': reason,
      'status': status,
      if (dateKey != null) 'dateKey': dateKey,
      if (lectureStartTime != null) 'lectureStartTime': lectureStartTime,
      if (lectureEndTime != null) 'lectureEndTime': lectureEndTime,
      if (className != null) 'className': className,
      if (semesterNumber != null) 'semesterNumber': semesterNumber,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (facultyPnr != null) 'facultyPnr': facultyPnr,
      if (batchKey != null) 'batchKey': batchKey,
      if (lectureKey != null) 'lectureKey': lectureKey,
      if (validFrom != null) 'validFrom': validFrom!.toIso8601String(),
      if (validTo != null) 'validTo': validTo!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
