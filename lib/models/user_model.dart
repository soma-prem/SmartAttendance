class AppUser {
  final String pnr;
  final String name;
  final String role; // 'admin', 'faculty', 'student'
  final bool isApproved;
  
  // Optional based on role
  final String? dob;
  final String? branch;
  final String? year;
  final int? semester;
  final String? division;
  final String? rollNo;
  final String? className;
  final String? batch; // Added for practical batches
  final String? phone;
  final String? parentPhone;
  final String? subject;

  AppUser({
    required this.pnr,
    required this.name,
    required this.role,
    this.isApproved = false,
    this.dob,
    this.branch,
    this.year,
    this.semester,
    this.division,
    this.rollNo,
    this.className,
    this.batch,
    this.phone,
    this.parentPhone,
    this.subject,
  });

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  String? get effectiveClassName {
    if (className != null && className!.trim().isNotEmpty) {
      return className!.trim();
    }

    if (branch != null &&
        branch!.trim().isNotEmpty &&
        division != null &&
        division!.trim().isNotEmpty) {
      return '${branch!.trim()}-${division!.trim()}';
    }

    return null;
  }

  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      pnr: data['pnr'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'student',
      isApproved: data['isApproved'] ?? false,
      dob: data['dob']?.toString(),
      branch: data['branch']?.toString(),
      year: data['year']?.toString(),
      semester: _parseNullableInt(data['semester']),
      division: data['division']?.toString(),
      rollNo: data['rollNo']?.toString(),
      className: data['className']?.toString() ?? data['class']?.toString(),
      batch: data['batch']?.toString(),
      phone: data['phone']?.toString(),
      parentPhone: data['parentPhone']?.toString(),
      subject: data['subject']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pnr': pnr,
      'name': name,
      'role': role,
      'isApproved': isApproved,
      if (dob != null) 'dob': dob,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (semester != null) 'semester': semester,
      if (division != null) 'division': division,
      if (rollNo != null) 'rollNo': rollNo,
      if (effectiveClassName != null) 'className': effectiveClassName,
      if (batch != null) 'batch': batch,
      if (phone != null) 'phone': phone,
      if (parentPhone != null) 'parentPhone': parentPhone,
      if (subject != null) 'subject': subject,
    };
  }
}
