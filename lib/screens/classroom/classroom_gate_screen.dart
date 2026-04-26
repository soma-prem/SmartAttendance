import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/classroom_auth_service.dart';
import '../../services/auth_service.dart';
import '../../utils/role_home_navigation.dart';
import 'faculty_classrooms_screen.dart';
import 'student_classrooms_screen.dart';

class ClassroomGateScreen extends StatefulWidget {
  const ClassroomGateScreen({super.key});

  @override
  State<ClassroomGateScreen> createState() => _ClassroomGateScreenState();
}

class _ClassroomGateScreenState extends State<ClassroomGateScreen> {
  bool _signingIn = false;

  Future<void> _signIn(ClassroomAuthService service) async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await service.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = context.watch<AuthService>().currentUser;
    if (appUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final classroomAuth = context.read<ClassroomAuthService>();

    return StreamBuilder(
      stream: classroomAuth.authStateChanges(),
      builder: (context, snapshot) {
        final googleUser = classroomAuth.currentUser;
        if (googleUser == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Go To Classroom'),
              leading: BackButton(
                onPressed: () => goToRoleHome(context, appUser.role),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.school_outlined,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Classroom',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sign in with Google to continue. You will stay signed in for future visits.',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed:
                                  _signingIn ? null : () => _signIn(classroomAuth),
                              icon: _signingIn
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(_signingIn ? 'Signing in...' : 'Sign in with Google'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => goToRoleHome(context, appUser.role),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (appUser.role == 'faculty') {
          return FacultyClassroomsScreen(user: appUser);
        }
        if (appUser.role == 'student') {
          return StudentClassroomsScreen(user: appUser);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Classroom'),
            leading: BackButton(
              onPressed: () => goToRoleHome(context, appUser.role),
            ),
          ),
          body: const Center(
            child: Text('Classroom is available for Student/Faculty only.'),
          ),
        );
      },
    );
  }
}
