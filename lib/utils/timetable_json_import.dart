import 'dart:convert';

import 'package:intl/intl.dart';

List<String> splitTutSubjects(String subjectName) {
  final raw = subjectName.trim();
  if (raw.isEmpty) return const [];
  if (!raw.toUpperCase().contains('(TUT)')) return [raw];
  if (!raw.contains('/')) return [raw.replaceAll(RegExp(r'\(TUT\)', caseSensitive: false), '').trim()];

  final parts = raw.split('/').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (parts.length != 2) return [raw];

  // Remove "(TUT)" token from both sides to match how subjects are normally stored (e.g., GP).
  final cleaned = parts
      .map((p) => p.replaceAll(RegExp(r'\(TUT\)', caseSensitive: false), '').trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (cleaned.length != 2) return [raw];
  return cleaned;
}

class TimetableImportSlot {
  final String type; // SUBJECT | PRACTICAL
  final String? batch; // null for SUBJECT
  final String day; // Monday..Saturday
  final String subjectName;
  final String startTime; // raw "HH:mm" or "hh:mm"
  final String endTime; // raw

  TimetableImportSlot({
    required this.type,
    required this.batch,
    required this.day,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
  });
}

class TimetableImportSubjectDetail {
  final String subjectName;
  final String abbreviation;
  final String facultyName;
  final String venue;

  TimetableImportSubjectDetail({
    required this.subjectName,
    required this.abbreviation,
    required this.facultyName,
    required this.venue,
  });
}

class TimetableImportData {
  final String department;
  final String yearLabel;
  final String division;
  final List<TimetableImportSlot> slots;
  final List<TimetableImportSubjectDetail> subjectDetails;

  TimetableImportData({
    required this.department,
    required this.yearLabel,
    required this.division,
    required this.slots,
    required this.subjectDetails,
  });
}

class TimetableAssignmentKey {
  final String subjectName;
  final String? batchName; // B1/B2/B3 for practical

  const TimetableAssignmentKey({required this.subjectName, this.batchName});

  bool get isPractical => batchName != null && batchName!.trim().isNotEmpty;

  String get id => isPractical
      ? '${subjectName.trim()}__${batchName!.trim()}'
      : subjectName.trim();

  @override
  bool operator ==(Object other) {
    return other is TimetableAssignmentKey && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

String normalizeBatchName(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  final lower = value.toLowerCase();
  if (lower == 'batch 1' || lower == 'batch1') return 'B1';
  if (lower == 'batch 2' || lower == 'batch2') return 'B2';
  if (lower == 'batch 3' || lower == 'batch3') return 'B3';
  return value.toUpperCase();
}

int? parseYearFromLabel(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (v.isEmpty) return null;
  // Matches: "2nd Year", "2 Year", "2nd", etc.
  final match = RegExp(r'(\d+)').firstMatch(v);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

TimetableImportData parseTimetableImportJson(String jsonText) {
  dynamic decoded;
  try {
    decoded = jsonDecode(jsonText);
  } catch (e) {
    throw FormatException('Invalid JSON: $e');
  }

  if (decoded is! Map) {
    throw const FormatException('JSON root must be an object.');
  }

  final map = decoded.cast<String, dynamic>();
  final department = (map['department'] ?? '').toString();
  final yearLabel = (map['year'] ?? '').toString();
  final division = (map['division'] ?? '').toString();

  final slotsRaw = map['slots'];
  if (slotsRaw is! List) {
    throw const FormatException('Missing/invalid "slots" array.');
  }

  final subjectDetailsRaw = map['subjectDetails'];
  if (subjectDetailsRaw is! List) {
    throw const FormatException('Missing/invalid "subjectDetails" array.');
  }

  final slots = <TimetableImportSlot>[];
  for (final item in slotsRaw) {
    if (item is! Map) continue;
    final m = item.cast<String, dynamic>();
    final type = (m['type'] ?? '').toString().trim().toUpperCase();
    final batch = (m['batch'] ?? '').toString();
    final day = (m['day'] ?? '').toString().trim();
    final subjectName = (m['subjectName'] ?? '').toString().trim();
    final startTime = (m['startTime'] ?? '').toString().trim();
    final endTime = (m['endTime'] ?? '').toString().trim();

    if (type.isEmpty ||
        day.isEmpty ||
        subjectName.isEmpty ||
        startTime.isEmpty ||
        endTime.isEmpty) {
      throw const FormatException(
        'Each slot must have type, day, subjectName, startTime, endTime.',
      );
    }

    final isPractical = type == 'PRACTICAL';
    final normalizedBatch =
        isPractical ? normalizeBatchName(batch).trim() : null;
    if (isPractical && (normalizedBatch == null || normalizedBatch.isEmpty)) {
      throw FormatException('Practical slot missing batch: $subjectName ($day)');
    }

    slots.add(
      TimetableImportSlot(
        type: type,
        batch: normalizedBatch?.isEmpty == true ? null : normalizedBatch,
        day: day,
        subjectName: subjectName,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  final subjectDetails = <TimetableImportSubjectDetail>[];
  for (final item in subjectDetailsRaw) {
    if (item is! Map) continue;
    final m = item.cast<String, dynamic>();
    final abbreviation = (m['abbreviation'] ?? '').toString();
    final subjectName = (m['subjectName'] ?? '').toString().trim();
    final facultyName = (m['facultyName'] ?? '').toString();
    final venue = (m['venue'] ?? '').toString();
    if (subjectName.isEmpty) continue;
    subjectDetails.add(
      TimetableImportSubjectDetail(
        subjectName: subjectName,
        abbreviation: abbreviation,
        facultyName: facultyName,
        venue: venue,
      ),
    );
  }

  return TimetableImportData(
    department: department,
    yearLabel: yearLabel,
    division: division,
    slots: slots,
    subjectDetails: subjectDetails,
  );
}

class ConvertedTime {
  final String formatted; // "hh:mm a"
  final int minutes; // minutes since 00:00 (0..1439)

  const ConvertedTime(this.formatted, this.minutes);
}

ConvertedTime convertLooseHhMmToDisplay({
  required String hhmm,
  int? previousMinutes,
}) {
  final value = hhmm.trim();
  final parts = value.split(':');
  if (parts.length != 2) {
    throw FormatException('Invalid time "$hhmm". Expected HH:mm.');
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    throw FormatException('Invalid time "$hhmm".');
  }
  if (minute < 0 || minute > 59) {
    throw FormatException('Invalid minutes in "$hhmm".');
  }

  int minutes = 0;

  // If hour is clearly 24h (13..23), treat as 24h. Otherwise assume timetable
  // uses a 12h-like rolling clock without AM/PM (e.g., 01:15 means 1:15 PM).
  if (hour >= 13 && hour <= 23) {
    minutes = hour * 60 + minute;
  } else if (hour == 0) {
    // Disallow 00:xx in college schedules; treat as invalid to avoid surprises.
    throw FormatException('Invalid hour in "$hhmm".');
  } else if (hour == 12) {
    minutes = 12 * 60 + minute;
  } else {
    minutes = hour * 60 + minute;
  }

  if (previousMinutes != null) {
    // If we've already crossed noon, keep small hours (1..6) in the afternoon.
    if (previousMinutes >= 12 * 60 && minutes < 7 * 60) {
      minutes += 12 * 60;
    }

    // Handle noon->1pm wrap (12:15 -> 01:15) and similar wraps.
    if (minutes < previousMinutes) {
      final wrapped = minutes + 12 * 60;
      // Only wrap if it makes sense (prevents wrapping back to next day).
      if (wrapped - previousMinutes <= 8 * 60) {
        minutes = wrapped;
      }
    }
  }

  // Clamp within a day
  minutes %= 24 * 60;
  final dt = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
  final formatted = DateFormat('hh:mm a').format(dt);
  return ConvertedTime(formatted, minutes);
}
