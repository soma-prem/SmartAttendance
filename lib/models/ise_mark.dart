class IseMark {
  final String id;
  final String courseKey;
  final String studentPnr;
  final String subject;
  final String className;
  final int semesterNumber;
  final int? ise1;
  final int? ise2;
  final int? ise3;
  final String? updatedByPnr;
  final String? updatedByName;
  final DateTime? updatedAt;

  IseMark({
    required this.id,
    required this.courseKey,
    required this.studentPnr,
    required this.subject,
    required this.className,
    required this.semesterNumber,
    this.ise1,
    this.ise2,
    this.ise3,
    this.updatedByPnr,
    this.updatedByName,
    this.updatedAt,
  });

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  factory IseMark.fromMap(String id, Map<String, dynamic> data) {
    return IseMark(
      id: id,
      courseKey: (data['courseKey'] ?? '').toString(),
      studentPnr: (data['studentPnr'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      className: (data['className'] ?? data['class'] ?? '').toString(),
      semesterNumber: _parseNullableInt(data['semesterNumber']) ?? 1,
      ise1: _parseNullableInt(data['ise1']),
      ise2: _parseNullableInt(data['ise2']),
      ise3: _parseNullableInt(data['ise3']),
      updatedByPnr: data['updatedByPnr']?.toString(),
      updatedByName: data['updatedByName']?.toString(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString())
          : null,
    );
  }
}
