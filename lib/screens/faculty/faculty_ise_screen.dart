import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ise_mark.dart';
import '../../models/model_answer_paper.dart';
import '../../models/timetable_entry.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_auth_service.dart';
import '../../services/db_service.dart';
import '../../services/drive_upload_service.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/faculty_sidebar_drawer.dart';

class FacultyIseScreen extends StatefulWidget {
  final String facultyPnr;
  final String facultyName;

  const FacultyIseScreen({
    super.key,
    required this.facultyPnr,
    required this.facultyName,
  });

  @override
  State<FacultyIseScreen> createState() => _FacultyIseScreenState();
}

class _CourseOption {
  final String subject;
  final String className;
  final int semesterNumber;
  final String courseKey;

  const _CourseOption({
    required this.subject,
    required this.className,
    required this.semesterNumber,
    required this.courseKey,
  });

  String get label => '$subject • $className • Sem $semesterNumber';
}

class _Controllers {
  final TextEditingController ise1;
  final TextEditingController ise2;
  final TextEditingController ise3;

  _Controllers({required this.ise1, required this.ise2, required this.ise3});

  void dispose() {
    ise1.dispose();
    ise2.dispose();
    ise3.dispose();
  }
}

class _FacultyIseScreenState extends State<FacultyIseScreen> {
  _CourseOption? _selectedCourse;
  final Map<String, _Controllers> _controllersByStudent = {};
  bool _isSaving = false;

  final _courseCode = TextEditingController();
  String _department = 'CSE';
  String _btechClass = 'SY BTECH';
  String _testNo = 'I';
  DateTime? _testDate;
  String? _pickedPath;
  String? _pickedFileName;
  bool _isUploadingModel = false;

  static const _departments = ['CSE', 'IT', 'ENTC', 'ECM', 'ME', 'CE'];
  static const _btechClasses = ['FY BTECH', 'SY BTECH', 'TY BTECH', 'FINAL'];
  static const _testNos = ['I', 'II', 'III'];

  @override
  void dispose() {
    for (final c in _controllersByStudent.values) {
      c.dispose();
    }
    _controllersByStudent.clear();
    _courseCode.dispose();
    super.dispose();
  }

  void _setSelectedCourse(_CourseOption? course) {
    if (_selectedCourse?.courseKey == course?.courseKey) return;
    for (final c in _controllersByStudent.values) {
      c.dispose();
    }
    _controllersByStudent.clear();
    setState(() => _selectedCourse = course);
  }

  int? _parseNullableInt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  Future<void> _save(List<AppUser> students) async {
    final course = _selectedCourse;
    if (course == null) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final scoresByStudent = <String, ({int? ise1, int? ise2, int? ise3})>{};
      for (final s in students) {
        final c = _controllersByStudent[s.pnr];
        if (c == null) continue;
        final raw1 = c.ise1.text.trim();
        final raw2 = c.ise2.text.trim();
        final raw3 = c.ise3.text.trim();
        if (raw1.isEmpty && raw2.isEmpty && raw3.isEmpty) continue;
        scoresByStudent[s.pnr] = (
          ise1: _parseNullableInt(raw1),
          ise2: _parseNullableInt(raw2),
          ise3: _parseNullableInt(raw3),
        );
      }

      if (scoresByStudent.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to update.')));
        return;
      }

      await DatabaseService().upsertIseMarks(
        courseKey: course.courseKey,
        subject: course.subject,
        className: course.className,
        semesterNumber: course.semesterNumber,
        updatedByPnr: widget.facultyPnr,
        updatedByName: widget.facultyName,
        scoresByStudentPnr: scoresByStudent,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ISE marks updated.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update ISE marks: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickModelFile() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final file = picked?.files.single;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    if (!mounted) return;
    setState(() {
      _pickedPath = path;
      _pickedFileName = file?.name ?? path.split(Platform.pathSeparator).last;
    });
  }

  Future<void> _uploadModelAnswerPaper() async {
    if (_isUploadingModel) return;

    final courseCode = _courseCode.text.trim();
    final date = _testDate;
    final path = _pickedPath;
    final pickedName = _pickedFileName;

    if (courseCode.isEmpty ||
        date == null ||
        path == null ||
        path.trim().isEmpty ||
        pickedName == null ||
        pickedName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all details and attach a file.')),
      );
      return;
    }

    setState(() => _isUploadingModel = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final auth = context.read<ClassroomAuthService>();
      final account = await auth.ensureGoogleAccount();
      if (account == null || account.email.trim().isEmpty) {
        throw Exception('Google sign-in cancelled.');
      }

      final driveService = context.read<DriveUploadService>();
      final upload = await driveService.uploadPublicMaterial(
        file: File(path),
        registeredEmail: account.email,
      );

      await DatabaseService().upsertModelAnswerPaper(
        courseCode: courseCode,
        department: _department,
        className: _btechClass,
        date: date,
        testNo: _testNo,
        fileName: upload.fileName,
        fileUrl: upload.webViewLink,
        uploadedByPnr: widget.facultyPnr,
        uploadedByName: widget.facultyName,
      );

      if (!mounted) return;
      setState(() {
        _pickedPath = null;
        _pickedFileName = null;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Model answer paper uploaded.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingModel = false);
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

  Future<void> _confirmAndDeleteModelPaper(ModelAnswerPaper paper) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete model answer paper?'),
        content: Text('Delete "${paper.fileName}" from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await DatabaseService().deleteModelAnswerPaper(paper.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _buildUploadModelAnswerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Model Answer Paper',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _courseCode,
              decoration: const InputDecoration(
                labelText: 'Course code',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _department,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _department = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _btechClass,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _btechClasses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _btechClass = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _testNo,
                    decoration: const InputDecoration(
                      labelText: 'Test No',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _testNos
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _testNo = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 1),
                        initialDate: _testDate ?? now,
                      );
                      if (picked == null) return;
                      if (!mounted) return;
                      setState(() => _testDate = picked);
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _testDate == null
                          ? 'Pick date'
                          : DatabaseService.dateDisplayDdMmYyyy(_testDate!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingModel ? null : _pickModelFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _pickedFileName?.trim().isNotEmpty == true
                          ? _pickedFileName!
                          : 'Attach file',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isUploadingModel ? null : _uploadModelAnswerPaper,
                  icon: _isUploadingModel
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_isUploadingModel ? 'Uploading...' : 'Upload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelAnswerHistory() {
    return StreamBuilder<List<ModelAnswerPaper>>(
      stream: DatabaseService().watchModelAnswerPapersForFaculty(
        widget.facultyPnr,
      ),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ModelAnswerPaper>[];
        items.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No model answer papers uploaded yet.'),
          );
        }

        return Column(
          children: items.map((p) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  p.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${p.courseCode} • ${p.department} • ${p.className} • ${p.dateDisplay} • ${p.testNo}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _openPaperUrl(p.fileUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Open',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openPaperUrl(p.fileUrl),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmAndDeleteModelPaper(p),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('ISE'),
      ),
      drawer: FacultySidebarDrawer(
        user: user,
        fallbackPnr: widget.facultyPnr,
        fallbackName: widget.facultyName,
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: DatabaseService().getTimetableForFaculty(widget.facultyPnr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? const [];
          if (data.isEmpty) {
            return const Center(child: Text('No timetable found.'));
          }

          final optionsMap = <String, _CourseOption>{};
          for (final e in data) {
            final subject = e.subject.trim();
            final className = e.className.trim();
            if (subject.isEmpty || className.isEmpty) continue;
            final courseKey = DatabaseService.buildIseCourseKey(
              subject: subject,
              className: className,
              semesterNumber: e.semesterNumber,
            );
            optionsMap.putIfAbsent(
              courseKey,
              () => _CourseOption(
                subject: subject,
                className: className,
                semesterNumber: e.semesterNumber,
                courseKey: courseKey,
              ),
            );
          }

          final options = optionsMap.values.toList()
            ..sort((a, b) {
              final s = a.subject.compareTo(b.subject);
              if (s != 0) return s;
              final c = a.className.compareTo(b.className);
              if (c != 0) return c;
              return a.semesterNumber.compareTo(b.semesterNumber);
            });

          if (options.isEmpty) {
            return const Center(child: Text('No courses found.'));
          }

          if (_selectedCourse == null ||
              !optionsMap.containsKey(_selectedCourse!.courseKey)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _setSelectedCourse(options.first);
            });
          }

          final effectiveCourse = _selectedCourse ?? options.first;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(effectiveCourse.courseKey),
                  initialValue: effectiveCourse.courseKey,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                  ),
                  items: options
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.courseKey,
                          child: Text(o.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    final next = optionsMap[val];
                    _setSelectedCourse(next);
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<List<IseMark>>(
                  stream: DatabaseService().watchIseMarksForCourse(
                    effectiveCourse.courseKey,
                  ),
                  builder: (context, marksSnap) {
                    final marks = marksSnap.data ?? const [];
                    final marksByStudent = <String, IseMark>{
                      for (final m in marks) m.studentPnr: m,
                    };

                    return FutureBuilder<List<AppUser>>(
                      future: DatabaseService().getStudentsByClass(
                        effectiveCourse.className,
                        semester: effectiveCourse.semesterNumber,
                      ),
                      builder: (context, studentsSnap) {
                        if (studentsSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final students = studentsSnap.data ?? const [];
                        if (students.isEmpty) {
                          return const Center(
                            child: Text('No students found.'),
                          );
                        }

                        students.sort((a, b) {
                          final ar = int.tryParse(a.rollNo ?? '');
                          final br = int.tryParse(b.rollNo ?? '');
                          if (ar != null && br != null) return ar.compareTo(br);
                          return (a.rollNo ?? '').compareTo(b.rollNo ?? '');
                        });

                        for (final s in students) {
                          final mark = marksByStudent[s.pnr];
                          final existing = _controllersByStudent[s.pnr];
                          if (existing == null) {
                            _controllersByStudent[s.pnr] = _Controllers(
                              ise1: TextEditingController(
                                text: mark?.ise1?.toString() ?? '',
                              ),
                              ise2: TextEditingController(
                                text: mark?.ise2?.toString() ?? '',
                              ),
                              ise3: TextEditingController(
                                text: mark?.ise3?.toString() ?? '',
                              ),
                            );
                          } else if (mark != null) {
                            if (existing.ise1.text.trim().isEmpty &&
                                mark.ise1 != null) {
                              existing.ise1.text = mark.ise1!.toString();
                            }
                            if (existing.ise2.text.trim().isEmpty &&
                                mark.ise2 != null) {
                              existing.ise2.text = mark.ise2!.toString();
                            }
                            if (existing.ise3.text.trim().isEmpty &&
                                mark.ise3 != null) {
                              existing.ise3.text = mark.ise3!.toString();
                            }
                          }
                        }

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ...students.map((s) {
                              final c = _controllersByStudent[s.pnr]!;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${s.name} (${s.rollNo ?? '-'})',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: c.ise1,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'ISE1',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: c.ise2,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'ISE2',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: c.ise3,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'ISE3',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            SafeArea(
                              top: false,
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : () => _save(students),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _isSaving ? 'Updating...' : 'Update',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildUploadModelAnswerCard(),
                            const SizedBox(height: 12),
                            Text(
                              'Upload History',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            _buildModelAnswerHistory(),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
