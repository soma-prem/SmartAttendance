import 'package:flutter/material.dart';

class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('android/app/src/main/res/load.gif'),
            width: 160,
            height: 160,
          ),
        ),
      ),
    );
  }
}

