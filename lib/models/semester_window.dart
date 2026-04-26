class SemesterWindow {
  final String branch;
  final int year;
  final int semester;
  final DateTime startDate;
  final DateTime endDate;

  SemesterWindow({
    required this.branch,
    required this.year,
    required this.semester,
    required this.startDate,
    required this.endDate,
  });

  factory SemesterWindow.fromMap(Map<String, dynamic> data) {
    return SemesterWindow(
      branch: data['branch'] ?? '',
      year: data['year'] ?? 0,
      semester: data['semester'] ?? 0,
      startDate: DateTime.parse(data['startDate']),
      endDate: DateTime.parse(data['endDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branch': branch,
      'year': year,
      'semester': semester,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }
}
