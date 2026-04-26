import 'dart:io';

import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/attendance_record.dart';
import '../models/user_model.dart';

class AttendancePdfService {
  static String _sanitize(String text) {
    final cleaned = text.trim();
    return cleaned.isEmpty
        ? 'NA'
        : cleaned.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  }

  static Future<void> generateAndDownloadAttendanceReport({
    required String facultyPnr,
    required String facultyName,
    required String title,
    required String periodLabel,
    required List<AttendanceRecord> records,
    required List<AppUser> students,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final generatedAt = DateFormat('MMM d, yyyy hh:mm a').format(now);

    final rows = <List<String>>[];
    final studentMap = {for (var student in students) student.pnr: student};

    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final pnr = student.pnr;
      final roll = student.rollNo?.trim().isEmpty == true ? '-' : student.rollNo!;
      final name = student.name.trim().isEmpty ? '-' : student.name;

      int totalCount = 0;
      int presentCount = 0;
      for (final record in records) {
        if (record.records.containsKey(pnr)) {
          totalCount++;
          if (record.records[pnr] == 'Present') {
            presentCount++;
          }
        }
      }

      if (totalCount == 0) {
        continue;
      }

      final missedCount = totalCount - presentCount;
      final percentage = totalCount == 0
          ? 0.0
          : (presentCount / totalCount) * 100.0;

      rows.add([
        '${rows.length + 1}',
        pnr,
        roll,
        name,
        '${percentage.toStringAsFixed(1)}%',
        '$missedCount',
        '$presentCount',
      ]);
    }

    if (rows.isEmpty) {
      throw Exception('No student attendance data available for selected weeks.');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Faculty: $facultyName ($facultyPnr)'),
                pw.Text('Report period: $periodLabel'),
                pw.Text('Generated: $generatedAt'),
                pw.SizedBox(height: 18),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                    6: pw.Alignment.center,
                  },
                  data: [
                    [
                      'Sr No',
                      'PNR',
                      'Roll No',
                      'Name',
                      'Attendance %',
                      'Missed',
                      'Present',
                    ],
                    ...rows,
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final safeFileName =
        'attendance_${_sanitize(facultyPnr)}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$safeFileName');
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  }

  static Future<void> generateAndDownloadClassCoordinatorReport({
    required String facultyPnr,
    required String facultyName,
    required String title,
    required String periodLabel,
    required List<AttendanceRecord> records,
    required List<AppUser> students,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final generatedAt = DateFormat('MMM d, yyyy hh:mm a').format(now);

    final subjects = records
        .map((r) => r.subject.trim())
        .where((subject) => subject.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final recordGroups = <String, List<AttendanceRecord>>{};
    for (final record in records) {
      final subjectKey = record.subject.trim();
      recordGroups.putIfAbsent(subjectKey, () => []).add(record);
    }

    final header = <String>[
      'Sr No',
      'PNR',
      'Roll No',
      'Name',
      ...subjects.map((subject) => '$subject (P/T)'),
      'Total %',
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final presentCounts = <String>[];
      var totalClasses = 0;
      var totalPresent = 0;

      for (final subject in subjects) {
        final subjectRecords = recordGroups[subject] ?? [];
        final totalForSubject = subjectRecords.length;
        final presentForSubject = subjectRecords
            .where((record) => record.records[student.pnr] == 'Present')
            .length;

        presentCounts.add('$presentForSubject/$totalForSubject');
        totalClasses += totalForSubject;
        totalPresent += presentForSubject;
      }

      final totalPercentage = totalClasses == 0
          ? 0.0
          : (totalPresent / totalClasses) * 100.0;

      rows.add([
        '${i + 1}',
        student.pnr,
        student.rollNo?.trim().isEmpty == true ? '-' : student.rollNo!,
        student.name.trim().isEmpty ? '-' : student.name,
        ...presentCounts,
        '${totalPercentage.toStringAsFixed(1)}%',
      ]);
    }

    if (rows.isEmpty) {
      throw Exception('No student attendance data available for selected weeks.');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Faculty: $facultyName ($facultyPnr)'),
                pw.Text('Report period: $periodLabel'),
                pw.Text('Generated: $generatedAt'),
                pw.SizedBox(height: 18),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                  },
                  data: [
                    [
                      ...header,
                    ],
                    ...rows,
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final safeFileName = 'cc_report_${_sanitize(facultyPnr)}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$safeFileName');
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  }
}
