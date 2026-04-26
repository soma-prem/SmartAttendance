import 'package:flutter/material.dart';

import '../../models/user_model.dart';

class StudentApplicationsScreen extends StatelessWidget {
  final AppUser student;

  const StudentApplicationsScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applications for ${student.name}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'This section is under construction.\nPlease check back later for student application details.',
            ),
          ],
        ),
      ),
    );
  }
}
