import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Services
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/classroom_auth_service.dart';
import 'services/classroom_service.dart';
import 'services/drive_upload_service.dart';

// Screens
import 'screens/auth/role_selection_screen.dart';
// Note: We will create the dashboard imports below as we code them
import 'screens/admin/admin_dashboard.dart';
import 'screens/faculty/faculty_dashboard.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/startup_splash_screen.dart';

// Theme
import 'utils/theme.dart';

Future<void> _initializeFirebaseAndNotifications() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set background message handler (must be a top-level function).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Push notifications should never prevent the app from opening.
  try {
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint('Push notification init failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initFuture = _initializeFirebaseAndNotifications();
  runApp(AppBootstrap(firebaseInit: initFuture));
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({
    super.key,
    required this.firebaseInit,
  });

  final Future<void> firebaseInit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'WITClasseroom',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const StartupSplashScreen(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            title: 'WITClasseroom',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: FirebaseInitErrorScreen(error: snapshot.error),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthService()),
            Provider(create: (_) => ClassroomAuthService()),
            Provider(create: (_) => ClassroomService()),
            ProxyProvider<ClassroomAuthService, DriveUploadService>(
              update: (context, auth, previous) => DriveUploadService(auth),
            ),
          ],
          child: const SmartAttendanceApp(),
        );
      },
    );
  }
}

class FirebaseInitErrorScreen extends StatelessWidget {
  const FirebaseInitErrorScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Startup Error')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The app failed to initialize Firebase.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Common fixes:\n'
              '- Ensure `android/app/google-services.json` exists and matches your applicationId.\n'
              '- Ensure iOS has `GoogleService-Info.plist` in Runner.\n'
              '- Re-run `flutterfire configure` if you changed package/bundle id.\n'
              '- Run `flutter clean` then rebuild.',
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }
}

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WITClasseroom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      routes: {
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/faculty_dashboard': (context) => const FacultyDashboard(),
        '/student_dashboard': (context) => const StudentDashboard(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isLoading) {
      return const StartupSplashScreen();
    }

    final user = authService.currentUser;

    if (user == null) {
      return const RoleSelectionScreen();
    } else {
      // Role-based routing
      if (user.role == 'admin') {
        return const AdminDashboard();
      } else if (user.role == 'faculty') {
        return const FacultyDashboard();
      } else {
        return const StudentDashboard();
      }
    }
  }
}
