import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartattendance/main.dart';
import 'package:smartattendance/services/auth_service.dart';

void main() {
  testWidgets('App compiles without error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final authService = AuthService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const MaterialApp(home: AuthWrapper()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
  });
}
