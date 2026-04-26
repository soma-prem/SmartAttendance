import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/classroom_models.dart';
import '../../services/classroom_service.dart';
import '../../utils/role_home_navigation.dart';

class FacultySubmissionsScreen extends StatelessWidget {
  final ClassroomRoom room;
  final ClassroomAssignment assignment;
  const FacultySubmissionsScreen({
    super.key,
    required this.room,
    required this.assignment,
  });

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid file URL')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        goToFacultyScheduleHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => goToFacultyScheduleHome(context)),
          title: Text('Submissions • ${assignment.title}'),
        ),
        body: StreamBuilder<List<ClassroomSubmission>>(
          stream: service.watchSubmissions(
            classroomId: room.id,
            assignmentId: assignment.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final submissions = snapshot.data ?? const <ClassroomSubmission>[];
            if (submissions.isEmpty) {
              return const Center(child: Text('No submissions yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: submissions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = submissions[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ListTile(
                    title: Text('${s.studentName} (${s.studentPnr})'),
                    subtitle: Text(
                      s.note?.trim().isNotEmpty == true ? s.note! : 'No note',
                    ),
                    trailing: (s.fileUrl ?? '').isEmpty
                        ? const Text('No file')
                        : TextButton(
                            onPressed: () => _open(context, s.fileUrl!),
                            child: const Text('Open'),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

