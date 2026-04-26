import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ise_mark.dart';
import '../../models/model_answer_paper.dart';
import '../../services/db_service.dart';
import 'student_model_answer_scan_screen.dart';

class StudentIseScreen extends StatefulWidget {
  final String studentPnr;

  const StudentIseScreen({super.key, required this.studentPnr});

  @override
  State<StudentIseScreen> createState() => _StudentIseScreenState();
}

class _StudentIseScreenState extends State<StudentIseScreen> {
  bool _isFindingPaper = false;
  ModelAnswerPaper? _paper;
  Map<String, dynamic>? _scanData;

  Future<void> _scanAndFindPaper() async {
    if (_isFindingPaper) return;

    final raw = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const StudentModelAnswerScanScreen()),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw Exception('Invalid QR data');
      data = Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid QR JSON: $e')));
      }
      return;
    }

    final courseCode = (data['courseCode'] ?? '').toString().trim();
    final department = (data['department'] ?? '').toString().trim();
    final className = (data['class'] ?? data['className'] ?? '')
        .toString()
        .trim();
    final date = (data['date'] ?? '').toString().trim(); // dd/MM/yyyy
    final testNo = (data['testNo'] ?? '').toString().trim();

    if (courseCode.isEmpty ||
        department.isEmpty ||
        className.isEmpty ||
        date.isEmpty ||
        testNo.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR is missing required fields.')),
        );
      }
      return;
    }

    setState(() {
      _isFindingPaper = true;
      _scanData = data;
      _paper = null;
    });

    try {
      final paper = await DatabaseService().getModelAnswerPaperByScanJsonFields(
        courseCode: courseCode,
        department: department,
        className: className,
        dateDdMmYyyy: date,
        testNo: testNo,
      );
      if (!mounted) return;
      if (paper == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No model answer paper found.')),
        );
      }
      setState(() => _paper = paper);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch model paper: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFindingPaper = false);
    }
  }

  Future<void> _openPaperUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid file link')));
      }
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ISE Marks')),
      body: StreamBuilder<List<IseMark>>(
        stream: DatabaseService().watchIseMarksForStudent(widget.studentPnr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final marks = snapshot.data ?? const <IseMark>[];
          marks.sort((a, b) {
            final s = a.subject.compareTo(b.subject);
            if (s != 0) return s;
            final c = a.className.compareTo(b.className);
            if (c != 0) return c;
            return a.semesterNumber.compareTo(b.semesterNumber);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (marks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('No ISE marks available yet.'),
                )
              else
                ...marks.map((m) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.subject,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text('${m.className} • Sem ${m.semesterNumber}'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _markChip(
                                  context,
                                  label: 'ISE1',
                                  value: m.ise1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _markChip(
                                  context,
                                  label: 'ISE2',
                                  value: m.ise2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _markChip(
                                  context,
                                  label: 'ISE3',
                                  value: m.ise3,
                                ),
                              ),
                            ],
                          ),
                          if (m.updatedAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Updated: ${m.updatedAt}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model Answer Paper',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan QR to open the model answer paper.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isFindingPaper ? null : _scanAndFindPaper,
                          icon: _isFindingPaper
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.qr_code_scanner),
                          label: Text(
                            _isFindingPaper
                                ? 'Searching...'
                                : 'Scan barcode/QR',
                          ),
                        ),
                      ),
                      if (_scanData != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Scanned: ${_scanData!['courseCode'] ?? ''} • ${_scanData!['department'] ?? ''} • ${_scanData!['class'] ?? _scanData!['className'] ?? ''} • ${_scanData!['date'] ?? ''} • ${_scanData!['testNo'] ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_paper != null) ...[
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(_paper!.fileName),
                          subtitle: Text(
                            '${_paper!.courseCode} • ${_paper!.department} • ${_paper!.className} • ${_paper!.dateDisplay} • ${_paper!.testNo}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Open',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => _openPaperUrl(_paper!.fileUrl),
                          ),
                          onTap: () => _openPaperUrl(_paper!.fileUrl),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _markChip(
    BuildContext context, {
    required String label,
    required int? value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value?.toString() ?? '-',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
