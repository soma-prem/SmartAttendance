import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StudentModelAnswerScanScreen extends StatefulWidget {
  const StudentModelAnswerScanScreen({super.key});

  @override
  State<StudentModelAnswerScanScreen> createState() =>
      _StudentModelAnswerScanScreenState();
}

class _StudentModelAnswerScanScreenState
    extends State<StudentModelAnswerScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Model Answer QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled) return;
              final barcode = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first
                  : null;
              final raw = barcode?.rawValue;
              if (raw == null || raw.trim().isEmpty) return;
              _handled = true;
              Navigator.pop(context, raw);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Align the QR code inside the frame.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
