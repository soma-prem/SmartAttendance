class SubjectAssignment {
  final String id;
  final String subject;
  final String facultyPnr;
  final String facultyName;
  final String branch;
  final String division;
  final int year;
  final int semesterNumber;
  final String className;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SubjectAssignment({
    required this.id,
    required this.subject,
    required this.facultyPnr,
    required this.facultyName,
    required this.branch,
    required this.division,
    required this.year,
    required this.semesterNumber,
    required this.className,
    required this.createdAt,
    this.updatedAt,
  });

  factory SubjectAssignment.fromMap(String id, Map<String, dynamic> data) {
    return SubjectAssignment(
      id: id,
      subject: data['subject'] ?? '',
      facultyPnr: data['facultyPnr'] ?? '',
      facultyName: data['facultyName'] ?? '',
      branch: data['branch'] ?? '',
      division: data['division'] ?? '',
      year: data['year'] ?? 1,
      semesterNumber: data['semesterNumber'] ?? 1,
      className: data['className'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'facultyPnr': facultyPnr,
      'facultyName': facultyName,
      'branch': branch,
      'division': division,
      'year': year,
      'semesterNumber': semesterNumber,
      'className': className,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
