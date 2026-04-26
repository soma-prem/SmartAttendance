class ModelAnswerPaper {
  final String id;
  final String courseCode;
  final String department;
  final String className;
  final String dateKey; // yyyy-MM-dd
  final String dateDisplay; // dd/MM/yyyy
  final String testNo; // I/II/III
  final String fileName;
  final String fileUrl;
  final String uploadedByPnr;
  final String uploadedByName;
  final DateTime uploadedAt;

  ModelAnswerPaper({
    required this.id,
    required this.courseCode,
    required this.department,
    required this.className,
    required this.dateKey,
    required this.dateDisplay,
    required this.testNo,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedByPnr,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  factory ModelAnswerPaper.fromMap(String id, Map<String, dynamic> data) {
    return ModelAnswerPaper(
      id: id,
      courseCode: (data['courseCode'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      className: (data['className'] ?? data['class'] ?? '').toString(),
      dateKey: (data['dateKey'] ?? '').toString(),
      dateDisplay: (data['dateDisplay'] ?? data['date'] ?? '').toString(),
      testNo: (data['testNo'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      fileUrl: (data['fileUrl'] ?? '').toString(),
      uploadedByPnr: (data['uploadedByPnr'] ?? '').toString(),
      uploadedByName: (data['uploadedByName'] ?? '').toString(),
      uploadedAt: data['uploadedAt'] != null
          ? DateTime.tryParse(data['uploadedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
