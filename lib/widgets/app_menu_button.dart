import 'package:flutter/material.dart';

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Menu',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  void _defaultPressed(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      scaffold.openDrawer();
      return;
    }

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => IconButton(
        tooltip: tooltip,
        icon: const Icon(Icons.menu),
        onPressed: onPressed ?? () => _defaultPressed(context),
      ),
    );
  }
}

