// lib/pages/barcode_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

class BarcodeScannerPage extends StatefulWidget {
  final bool isContinuous;
  final Function(String) onBarcodeScanned;

  const BarcodeScannerPage({
    super.key,
    required this.isContinuous,
    required this.onBarcodeScanned,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController? _scannerController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _scanResult = '';
  bool _isScanning = true; // Controls whether scanner is active
  bool _hasScannedOnce = false; // Track if we've scanned at least once

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/scan.mp3'));
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  void _processBarcodeResult(String scannedValue) {
    if (!_isScanning) return; // Don't process if scanner is paused
    
    setState(() {
      _scanResult = scannedValue;
      _hasScannedOnce = true;
    });

    debugPrint("Barcode scanned: $scannedValue");
    _playSuccessSound();

    // Call the callback
    widget.onBarcodeScanned(scannedValue);

    if (!widget.isContinuous) {
      // For normal scan, close after a delay
      _scannerController?.stop();
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } else {
      // For continuous scan, STOP and wait for manual "Next Scan"
      _scannerController?.stop();
      setState(() {
        _isScanning = false; // Pause scanning
      });
      
      // Show feedback
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned: $scannedValue'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      debugPrint("Continuous scan paused - waiting for user to press 'Next Scan'");
    }
  }

  void _resumeScanning() {
    if (_scannerController != null && mounted) {
      _scannerController!.start();
      setState(() {
        _isScanning = true; // Resume scanning
      });
      debugPrint("Scanner resumed for next scan");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isContinuous ? 'Continuous Scan' : 'Scan Barcode',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _scannerController?.dispose();
            Navigator.pop(context);
            debugPrint("Scan cancelled by user");
          },
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController?.torchState ?? ValueNotifier(TorchState.off),
              builder: (context, state, child) {
                switch (state as TorchState) {
                  case TorchState.off:
                    return const Icon(
                      Icons.flash_off,
                      color: Colors.grey,
                    );
                  case TorchState.on:
                    return const Icon(
                      Icons.flash_on,
                      color: Colors.yellow,
                    );
                }
              },
            ),
            onPressed: () => _scannerController?.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                      _processBarcodeResult(barcodes[0].rawValue!);
                    }
                  },
                ),
                // Scanner overlay
                CustomPaint(
                  painter: ScannerOverlayPainter(
                    borderColor: widget.isContinuous ? Colors.green : Colors.red,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 300,
                  ),
                  child: Container(),
                ),
                // Paused indicator overlay for continuous mode
                if (widget.isContinuous && !_isScanning && _hasScannedOnce)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pause_circle_filled,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Scanner Paused',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Press "Next Scan" to continue',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Continuous scan controls
          if (widget.isContinuous)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Column(
                children: [
                  if (_scanResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Last scan: $_scanResult',
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: !_isScanning ? _resumeScanning : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_isScanning ? Colors.white : Colors.grey,
                        ),
                        child: Text(
                          'Next Scan',
                          style: TextStyle(
                            color: !_isScanning ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _scannerController?.dispose();
                          Navigator.pop(context);
                          debugPrint("Continuous scanning completed by user");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Scanner overlay painter (unchanged)
class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final double cutOutLeft = (size.width - cutOutSize) / 2;
    final double cutOutTop = (size.height - cutOutSize) / 2;
    final double cutOutRight = cutOutLeft + cutOutSize;
    final double cutOutBottom = cutOutTop + cutOutSize;

    // Create background with cutout
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutSize, cutOutSize),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw corner borders
    canvas.drawPath(
      Path()
        ..moveTo(cutOutLeft, cutOutTop + borderLength)
        ..lineTo(cutOutLeft, cutOutTop)
        ..lineTo(cutOutLeft + borderLength, cutOutTop),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cutOutRight - borderLength, cutOutTop)
        ..lineTo(cutOutRight, cutOutTop)
        ..lineTo(cutOutRight, cutOutTop + borderLength),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cutOutRight, cutOutBottom - borderLength)
        ..lineTo(cutOutRight, cutOutBottom)
        ..lineTo(cutOutRight - borderLength, cutOutBottom),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cutOutLeft + borderLength, cutOutBottom)
        ..lineTo(cutOutLeft, cutOutBottom)
        ..lineTo(cutOutLeft, cutOutBottom - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}