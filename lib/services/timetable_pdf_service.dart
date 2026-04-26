import 'dart:io';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/timetable_entry.dart';

class TimetablePdfService {
  static String _sanitizeFilePart(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 'NA';
    }

    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  }

  static Future<void> generateAndDownloadTimetable({
    required String branch,
    required int year,
    required int semester,
    required List<TimetableEntry> timetable,
  }) async {
    final pdf = pw.Document();

    // 1. Group and sort entries
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    // Get all unique start times to use as columns
    final allTimes = timetable.map((e) => e.startTime).toSet().toList();
    allTimes.sort((a, b) {
      try {
        final ta = DateFormat('hh:mm a').parse(a);
        final tb = DateFormat('hh:mm a').parse(b);
        return ta.compareTo(tb);
      } catch (_) {
        return 0;
      }
    });

    DateTime? tryParseTime(String raw) {
      var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final match = RegExp(
        r'^(\d{1,2}:\d{2})\s*(am|pm)$',
        caseSensitive: false,
      ).firstMatch(s);
      if (match != null) {
        s = '${match.group(1)} ${match.group(2)!.toUpperCase()}';
      }

      for (final fmt in <String>['h:mm a', 'hh:mm a']) {
        try {
          return DateFormat(fmt).parseStrict(s);
        } catch (_) {}
      }
      return null;
    }

    String normalizeTimeLabel(String raw) {
      final dt = tryParseTime(raw);
      if (dt == null) {
        return raw.trim();
      }

      final formatted = DateFormat('h:mm a').format(dt);
      return formatted.replaceAll('am', 'AM').replaceAll('pm', 'PM');
    }

    String mostCommonEndTimeLabel(String startTime) {
      final matches = timetable.where((e) => e.startTime == startTime).toList();
      if (matches.isEmpty) {
        return '';
      }

      final freq = <String, int>{};
      for (final e in matches) {
        freq[e.endTime] = (freq[e.endTime] ?? 0) + 1;
      }

      var best = matches.first.endTime;
      var bestCount = 0;
      freq.forEach((end, count) {
        if (count > bestCount) {
          best = end;
          bestCount = count;
        }
      });

      return normalizeTimeLabel(best);
    }

    allTimes.sort((a, b) {
      final ta = tryParseTime(a);
      final tb = tryParseTime(b);
      if (ta == null || tb == null) {
        return a.compareTo(b);
      }
      return ta.compareTo(tb);
    });

    int maxEntriesPerCell = 0;
    for (final day in days) {
      for (final time in allTimes) {
        final count = timetable
            .where(
              (e) =>
                  e.day.toLowerCase() == day.toLowerCase() &&
                  e.startTime == time,
            )
            .length;
        maxEntriesPerCell = math.max(maxEntriesPerCell, count);
      }
    }

    const pageMargin = 10.0;
    const headerHeight = 48.0;
    const footerHeight = 16.0;
    const gapsHeight = 10.0;

    final timeColWidth = 92.0;
    final dayColWidth = 118.0;

    final availableWidth = PdfPageFormat.a4.landscape.width - (pageMargin * 2);
    final availableHeight =
        PdfPageFormat.a4.landscape.height -
        (pageMargin * 2) -
        headerHeight -
        footerHeight -
        gapsHeight;

    final tableRows = allTimes.length + 1; // header + times
    final neededWidth = timeColWidth + (days.length * dayColWidth);
    final baseRowHeight = 24.0;
    final extraPerEntry = 12.0;
    final estimatedRowHeight =
        baseRowHeight + math.max(0, maxEntriesPerCell - 1) * extraPerEntry;
    final neededHeight = tableRows * estimatedRowHeight;

    final scaleW = availableWidth / neededWidth;
    final scaleH = availableHeight / neededHeight;
    final scale = math.min(scaleW, scaleH).clamp(0.60, 1.25).toDouble();

    // 2. Build PDF Content
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(pageMargin),
        build: (pw.Context context) {
          final lectureBoxDecoration = pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            border: pw.Border.all(color: PdfColors.blue200, width: 0.55),
          );

          final practicalBoxDecoration = pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            border: pw.Border.all(color: PdfColors.orange200, width: 0.55),
          );

          final table = pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: pw.FixedColumnWidth(timeColWidth),
              for (int i = 0; i < days.length; i++)
                i + 1: pw.FixedColumnWidth(dayColWidth),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Time',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  ...days.map(
                    (day) => pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                        child: pw.Text(
                          day,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ...allTimes.map((time) {
                return pw.TableRow(
                  children: [
                    pw.Container(
                      color: PdfColors.grey200,
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                        child: pw.Text(
                          () {
                            final start = normalizeTimeLabel(time);
                            final end = mostCommonEndTimeLabel(time);
                            return end.isEmpty ? start : '$start - $end';
                          }(),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                    ...days.map((day) {
                      final entries = timetable
                          .where(
                            (e) =>
                                e.day.toLowerCase() == day.toLowerCase() &&
                                e.startTime == time,
                          )
                          .toList();

                      if (entries.isEmpty) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.SizedBox(),
                        );
                      }

                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: () {
                            final lectureEntries = entries
                                .where((e) => e.batchName == null)
                                .toList();
                            final practicalEntries = entries
                                .where((e) => e.batchName != null)
                                .toList();

                            pw.Widget lectureText(TimetableEntry e) {
                              return pw.Text(
                                e.subject,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                                textAlign: pw.TextAlign.center,
                                maxLines: 2,
                              );
                            }

                            pw.Widget practicalText(TimetableEntry e) {
                              final label = e.batchName == null
                                  ? e.subject
                                  : '${e.subject} (${e.batchName})';
                              return pw.Text(
                                label,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.orange900,
                                ),
                                textAlign: pw.TextAlign.center,
                                maxLines: 2,
                              );
                            }

                            final children = <pw.Widget>[];

                            if (lectureEntries.isNotEmpty) {
                              children.add(
                                pw.Container(
                                  width: double.infinity,
                                  padding: const pw.EdgeInsets.all(4),
                                  decoration: lectureBoxDecoration,
                                  child: pw.Column(
                                    children: [
                                      for (
                                        int i = 0;
                                        i < lectureEntries.length;
                                        i++
                                      ) ...[
                                        lectureText(lectureEntries[i]),
                                        if (i != lectureEntries.length - 1)
                                          pw.Container(
                                            margin:
                                                const pw.EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                            height: 0.5,
                                            color: PdfColors.blue200,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (practicalEntries.isNotEmpty) {
                              children.add(
                                pw.Container(
                                  width: double.infinity,
                                  padding: const pw.EdgeInsets.all(4),
                                  decoration: practicalBoxDecoration,
                                  child: pw.Column(
                                    children: [
                                      for (
                                        int i = 0;
                                        i < practicalEntries.length;
                                        i++
                                      ) ...[
                                        practicalText(practicalEntries[i]),
                                        if (i != practicalEntries.length - 1)
                                          pw.Container(
                                            margin:
                                                const pw.EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                            height: 0.6,
                                            color: PdfColors.orange200,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            return children;
                          }(),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'COLLEGE TIMETABLE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Branch: $branch | Year: $year | Semester: $semester',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(thickness: 1, color: PdfColors.blue900),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Transform.scale(scale: scale, child: table),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by Smart Attendance System',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    'Page 1 of 1',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // 3. Save and Open
    try {
      final dir = Platform.isAndroid
          ? await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory()
          : await getApplicationDocumentsDirectory();

      await dir.create(recursive: true);

      final safeBranch = _sanitizeFilePart(branch);
      final file = File(
        "${dir.path}/timetable_${safeBranch}_Y${year}_S$semester.pdf",
      );
      await file.writeAsBytes(await pdf.save());

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      throw Exception("Could not generate PDF: $e");
    }
  }
}
