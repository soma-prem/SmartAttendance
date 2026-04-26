class TimetableEntry {
  final String id;
  final String day; // 'Monday', 'Tuesday', etc. (1-6 for 6-day week)
  final String startTime; // e.g., '10:00 AM'
  final String endTime; // e.g., '11:00 AM'
  final String subject;
  final String facultyPnr;
  final String facultyName;
  final String className;
  final String? batchName; // Added for practical batches
  final int semesterNumber;
  final int year;
  final String branch;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TimetableEntry({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.facultyPnr,
    required this.facultyName,
    required this.className,
    this.batchName,
    required this.semesterNumber,
    required this.year,
    required this.branch,
    required this.createdAt,
    this.updatedAt,
  });

  factory TimetableEntry.fromMap(String id, Map<String, dynamic> data) {
    return TimetableEntry(
      id: id,
      day: data['day'] ?? '',
      startTime: data['startTime'] ?? data['time'] ?? '', // Backward compatibility
      endTime: data['endTime'] ?? '',
      subject: data['subject'] ?? '',
      facultyPnr: data['facultyPnr'] ?? '',
      facultyName: data['facultyName'] ?? '',
      className: data['class'] ?? data['className'] ?? '',
      batchName: data['batchName'],
      semesterNumber: data['semesterNumber'] ?? 1,
      year: data['year'] ?? 1,
      branch: data['branch'] ?? '',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'facultyPnr': facultyPnr,
      'facultyName': facultyName,
      'class': className,
      'className': className,
      if (batchName != null) 'batchName': batchName,
      'semesterNumber': semesterNumber,
      'year': year,
      'branch': branch,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Helper to get day number (Monday = 1, ..., Saturday = 6)
  int getDayNumber() {
    const days = {'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4, 'Friday': 5, 'Saturday': 6};
    return days[day] ?? 0;
  }

  // Helper to format time for display
  String getTimeSlot() => '$startTime - $endTime';
}
