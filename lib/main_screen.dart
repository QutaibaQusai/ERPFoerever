import 'package:ERPForever/approval_page.dart';
import 'package:ERPForever/main.dart';
import 'package:ERPForever/test_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<WebViewController> _controllers;
  String _scanResult = '';

  MobileScannerController? _scannerController;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isContinuousScanMode = false;

  List<bool> _isLoading = List.generate(5, (_) => true);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (index) {
      final controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..addJavaScriptChannel(
              'BarcodeScanner',
              onMessageReceived: (JavaScriptMessage message) {
                if (message.message == 'scan') {
                  _isContinuousScanMode = false;
                  _scanBarcodeNormal();
                } else if (message.message == 'scanContinuous') {
                  _isContinuousScanMode = true;
                  _scanBarcodeNormal();
                }
              },
            )
            ..addJavaScriptChannel(
              'ThemeManager',
              onMessageReceived: (JavaScriptMessage message) {
                if (message.message == 'dark') {
                  _updateAppTheme('dark');
                } else if (message.message == 'light') {
                  _updateAppTheme('light');
                } else if (message.message == 'system') {
                  _updateAppTheme('system');
                }
              },
            )
            ..addJavaScriptChannel(
              'AlertManager',
              onMessageReceived: (JavaScriptMessage message) {
                try {
                  final params = message.message.split('|');
                  final alertMessage = params[0];
                  final title = params.length > 1 ? params[1] : 'Notification';
                  final btnText = params.length > 2 ? params[2] : 'OK';

                  _showAlert(alertMessage, title, btnText);
                } catch (e) {
                  print("Error processing alert message: $e");
                  _showAlert(message.message, 'Notification', 'OK');
                }
              },
            )
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageStarted: (String url) {
                  setState(() {
                    _isLoading[index] = true;
                  });
                  print("Page started loading: $url");
                },
                onNavigationRequest: (NavigationRequest request) {
                  print("Navigation to: ${request.url}");

                  if (request.url.startsWith('dark-mode://')) {
                    _updateAppTheme('dark');
                    return NavigationDecision.prevent;
                  } else if (request.url.startsWith('light-mode://')) {
                    _updateAppTheme('light');
                    return NavigationDecision.prevent;
                  } else if (request.url.startsWith('system-mode://')) {
                    _updateAppTheme('system');
                    return NavigationDecision.prevent;
                  } else if (request.url.startsWith('new-web://')) {
                    _navigateToTestPage(request.url);
                    return NavigationDecision.prevent;
                  } else if (request.url.startsWith('new-sheet://')) {
                    _showWebViewSheet('https://mujeer.com');
                    return NavigationDecision.prevent;
                  } else if (request.url.startsWith('alert://')) {
                    _showAlertFromUrl(request.url);
                    return NavigationDecision.prevent;
                  }

                  if (request.url.contains('barcode') ||
                      request.url.contains('scan')) {
                    print("Barcode scan triggered by URL");

                    _isContinuousScanMode = request.url.contains('continuous');
                    _scanBarcodeNormal();
                    return NavigationDecision
                        .prevent; 
                  }
                  return NavigationDecision
                      .navigate; 
                },
                onPageFinished: (String url) {
                  setState(() {
                    _isLoading[index] = false;
                  });
                  print("Page finished loading: $url");

                  _controllers[index].runJavaScript('''
                  // Add combined listener for theme change buttons and new-web links
                  document.addEventListener('click', function(e) {
                    let element = e.target;
                    for (let i = 0; i < 4 && element; i++) { // Check up to 3 levels up
                      // Check if element has href attribute that matches theme modes or new-web
                      const href = element.getAttribute('href');
                      if (href) {
                        if (href.startsWith('dark-mode://')) {
                          e.preventDefault();
                          console.log('Dark mode requested');
                          window.ThemeManager.postMessage('dark');
                          return false;
                        } else if (href.startsWith('light-mode://')) {
                          e.preventDefault();
                          console.log('Light mode requested');
                          window.ThemeManager.postMessage('light');
                          return false;
                        } else if (href.startsWith('system-mode://')) {
                          e.preventDefault();
                          console.log('System mode requested');
                          window.ThemeManager.postMessage('system');
                          return false;
                        } else if (href.startsWith('new-web://')) {
                          e.preventDefault();
                          console.log('Test page navigation requested: ' + href);
                          // Navigate to the link directly
                          window.location.href = href;
                          return false;
                        } else if (href.startsWith('new-sheet://')) {
                          e.preventDefault();
                          console.log('Sheet view requested: ' + href);
                          // Navigate to the link directly
                          window.location.href = href;
                          return false;
                        }
                      }
                      element = element.parentElement;
                    }
                  }, true);
                  
                  console.log("Theme and navigation handling JS initialized");
                ''');

                  _controllers[index].runJavaScript('''
                  // Add support for both handleBarcodeResult and getBarcode methods
                  window.handleBarcodeResult = function(result) {
                    console.log("Barcode scanned (handleBarcodeResult): " + result);
                    
                    // Check if getBarcode function exists and call it
                    if (typeof getBarcode === 'function') {
                      console.log("Calling getBarcode() with result: " + result);
                      getBarcode(result);
                    } else {
                      console.log("getBarcode() function not found, falling back to default behavior");
                      // Default behavior - fill input fields
                      var barcodeInputs = document.querySelectorAll('input[type="text"]');
                      if(barcodeInputs.length > 0) {
                        barcodeInputs[0].value = result;
                        barcodeInputs[0].dispatchEvent(new Event('input'));
                      }
                      
                      // Trigger custom event
                      var event = new CustomEvent('barcodeScanned', { detail: { result: result } });
                      document.dispatchEvent(event);
                    }
                  };
                  
                  // Support for continuous scanning mode
                  window.handleContinuousBarcodeResult = function(result) {
                    console.log("Continuous barcode scan: " + result);
                    
                    // Check if getBarcodeContinuous function exists and call it
                    if (typeof getBarcodeContinuous === 'function') {
                      console.log("Calling getBarcodeContinuous() with result: " + result);
                      getBarcodeContinuous(result);
                    } else {
                      console.log("getBarcodeContinuous() not found, falling back to getBarcode");
                      // Try regular getBarcode as fallback
                      if (typeof getBarcode === 'function') {
                        getBarcode(result);
                      }
                    }
                  };
                  
                  // Add button click listeners for barcode scanning
                  document.addEventListener('click', function(e) {
                    // Check if the clicked element or its parent has barcode-related attributes
                    let element = e.target;
                    for (let i = 0; i < 4 && element; i++) { // Check up to 3 levels up
                      if (element.getAttribute('href')?.includes('barcode') || 
                          element.getAttribute('href')?.includes('scan') ||
                          element.id?.includes('barcode') ||
                          element.id?.includes('scan') ||
                          element.className?.includes('barcode') ||
                          element.className?.includes('scan')) {
                        e.preventDefault();
                        
                        // Check if continuous scanning is requested
                        if (element.getAttribute('href')?.includes('continuous') || 
                            element.id?.includes('continuous') ||
                            element.className?.includes('continuous')) {
                          window.BarcodeScanner.postMessage('scanContinuous');
                        } else {
                          window.BarcodeScanner.postMessage('scan');
                        }
                        return false;
                      }
                      element = element.parentElement;
                    }
                  }, true);
                  
                  console.log("Barcode handling JS initialized");
                ''');
                  print("JavaScript injected to page: $url");
                },
                onWebResourceError: (WebResourceError error) {
                  print("Web resource error: ${error.description}");
                  setState(() {
                    _isLoading[index] = false;
                  });
                },
              ),
            )
            ..loadRequest(Uri.parse('https://erpforever.com/mobile'));

      return controller;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _showAlert(String message, String title, String buttonText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          title: Text(
            title,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          actions: [
            TextButton(
              child: Text(
                buttonText,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      },
    );
  }

  void _showAlertFromUrl(String url) {
    String message = "Alert";
    String title = "Notification";
    String btnText = "OK";

    try {
      Uri uri = Uri.parse(url.replaceFirst('alert://', 'https://alert.com?'));

      if (uri.queryParameters.containsKey('message')) {
        message = Uri.decodeComponent(uri.queryParameters['message']!);
      }

      if (uri.queryParameters.containsKey('title')) {
        title = Uri.decodeComponent(uri.queryParameters['title']!);
      }

      if (uri.queryParameters.containsKey('btn')) {
        btnText = Uri.decodeComponent(uri.queryParameters['btn']!);
      }
    } catch (e) {
      print("Error parsing alert URL: $e");
    }

    _showAlert(message, title, btnText);
  }
void _showWebViewSheet(String url) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _WebViewSheetContent(
        url: url,
        isDarkMode: isDarkMode,
        onThemeChange: _updateAppTheme,
        onNavigateToTestPage: (pageUrl) {
          Navigator.pop(context);
          _navigateToTestPage(pageUrl);
        },
      );
    },
  );
}
 
  
  void _navigateToTestPage(String url) {
 
    String targetUrl = 'https://www.erpforever.com/mobile/test';

    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-web://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        print("Error parsing URL parameters: $e");
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TestPage(url: targetUrl)),
    );
  }

  void _updateAppTheme(String themeMode) {
    MyApp.of(context).updateThemeMode(themeMode);
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/scan.mp3'));
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  void _processBarcodeResult(String scannedValue, BuildContext scannerContext) {
    print("Barcode scanned: $scannedValue");

    _playSuccessSound();

    if (!_isContinuousScanMode) {
      _scannerController?.stop();

      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(scannerContext).pop();

        setState(() {
          _scanResult = scannedValue;
        });

        _controllers[_selectedIndex].runJavaScript('''
          if (typeof getBarcode === 'function') {
            getBarcode("$scannedValue");
            console.log("Called getBarcode() with: $scannedValue");
          } else {
            window.handleBarcodeResult("$scannedValue");
            console.log("getBarcode() not found, used handleBarcodeResult instead");
          }
        ''');

        print("Barcode result sent to WebView: $scannedValue");
      });
    } else {
      _scannerController?.stop();

      setState(() {
        _scanResult = scannedValue;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      _controllers[_selectedIndex].runJavaScript('''
        window.handleContinuousBarcodeResult("$scannedValue");
        console.log("Called handleContinuousBarcodeResult with: $scannedValue");
      ''');

      print("Continuous barcode result sent to WebView: $scannedValue");
    }
  }

  void _resumeScanning() {
    if (_scannerController != null) {
      _scannerController!.start();
      print("Scanner resumed for next scan");
    }
  }

  Future<void> _scanBarcodeNormal() async {
    if (!_isContinuousScanMode) {
      setState(() {
        _scanResult = '';
      });
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (BuildContext scannerContext) {
          _scannerController = MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
            torchEnabled: false,
          );

          return StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _isContinuousScanMode ? 'Continuous Scan' : 'Scan Barcode',
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _scannerController?.dispose();
                      Navigator.pop(context);
                      print("Scan cancelled by user");
                    },
                  ),
                  actions: [
                    IconButton(
                      icon: ValueListenableBuilder(
                        valueListenable:
                            _scannerController?.torchState ??
                            ValueNotifier(TorchState.off),
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

                              if (barcodes.isNotEmpty &&
                                  barcodes[0].rawValue != null) {
                                _processBarcodeResult(
                                  barcodes[0].rawValue!,
                                  scannerContext,
                                );
                              }
                            },
                          ),

                          CustomPaint(
                            painter: ScannerOverlayPainter(
                              borderColor:
                                  _isContinuousScanMode
                                      ? Colors.green
                                      : Colors.red,
                              borderRadius: 10,
                              borderLength: 30,
                              borderWidth: 10,
                              cutOutSize: 300,
                            ),
                            child: Container(),
                          ),
                        ],
                      ),
                    ),

                    if (_isContinuousScanMode)
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 8.0,
                        ),
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
                                  onPressed: () {
                                    _resumeScanning();
                                    setState(() {
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Text('Next Scan'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    _scannerController?.dispose();
                                    Navigator.pop(context);
                                    print(
                                      "Continuous scanning completed by user",
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 2) return;

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ApprovalDetailsPage()),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAddOptions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      'Status',
                      FluentIcons.document_16_regular,
                      Colors.green,
                    ),
                    _buildActionButton(
                      'Time Log',
                      FluentIcons.clock_16_regular,
                      Colors.blue,
                    ),
                    _buildActionButton(
                      'Leave',
                      FluentIcons.weather_partly_cloudy_day_16_regular,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: isDarkMode ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? Colors.black : Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Loading...",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    switch (_selectedIndex) {
      case 0: 
        return AppBar(
          centerTitle: false,
          title: Container(
            height: 20,
            child: Image.asset(
              isDarkMode
                  ? "assets/erpforever-white.png"
                  : "assets/header_icon.png",
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(FluentIcons.search_24_regular),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(FluentIcons.alert_24_regular),
              onPressed: () {},
            ),
          ],
        );

      case 1: 
        return AppBar(
          centerTitle: false,
          title: Text(
            "Services",
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(FluentIcons.search_24_regular),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(FluentIcons.alert_24_regular),
              onPressed: () {},
            ),
          ],
        );

      case 3: 
        return AppBar(
          centerTitle: false,
          title: Text(
            "Approvals",
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(FluentIcons.filter_24_regular),
              onPressed: () {},
            ),
          ],
        );

      case 4: 
        return AppBar(
          centerTitle: false,
          title: Text(
            "Settings",
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(FluentIcons.power_24_regular, color: Colors.red),
              onPressed: () {},
            ),
          ],
        );

      default:
        return AppBar(title: Text("Home", style: TextStyle(color: titleColor)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Stack(
            children: [
              WebViewWidget(controller: _controllers[0]),
              if (_isLoading[0]) _buildLoadingIndicator(),
            ],
          ),

          Stack(
            children: [
              WebViewWidget(controller: _controllers[1]),
              if (_isLoading[1]) _buildLoadingIndicator(),
            ],
          ),

          const SizedBox.shrink(),

          Stack(
            children: [
              WebViewWidget(controller: _controllers[3]),
              if (_isLoading[3]) _buildLoadingIndicator(),
            ],
          ),

          Stack(
            children: [
              WebViewWidget(controller: _controllers[4]),
              if (_isLoading[4]) _buildLoadingIndicator(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 8,
        height: 60,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildNavItem(0, FluentIcons.home_24_regular, 'Home'),
            ),
            Expanded(
              child: _buildNavItem(1, FluentIcons.grid_24_regular, 'Services'),
            ),

            Expanded(
              child: GestureDetector(
                onTap: _showAddOptions,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white : Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: isDarkMode ? Colors.black : Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _buildNavItem(
                3,
                FluentIcons.checkbox_checked_24_regular,
                'Approvals',
              ),
            ),
            Expanded(
              child: _buildNavItem(
                4,
                FluentIcons.more_horizontal_24_regular,
                'More',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    final Color iconColor =
        isSelected
            ? Colors.blue
            : Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]!
            : Colors.grey;

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        HapticFeedback.lightImpact();
        _onItemTapped(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final Paint backgroundPaint =
        Paint()..color = Colors.black.withOpacity(0.5);

    final Paint borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final double cutOutLeft = (size.width - cutOutSize) / 2;
    final double cutOutTop = (size.height - cutOutSize) / 2;
    final double cutOutRight = cutOutLeft + cutOutSize;
    final double cutOutBottom = cutOutTop + cutOutSize;

    final Path backgroundPath =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutSize, cutOutSize),
              Radius.circular(borderRadius),
            ),
          )
          ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

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
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class _WebViewSheetContent extends StatefulWidget {
  final String url;
  final bool isDarkMode;
  final Function(String) onThemeChange;
  final Function(String) onNavigateToTestPage;

  const _WebViewSheetContent({
    required this.url,
    required this.isDarkMode,
    required this.onThemeChange,
    required this.onNavigateToTestPage,
  });

  @override
  _WebViewSheetContentState createState() => _WebViewSheetContentState();
}

class _WebViewSheetContentState extends State<_WebViewSheetContent> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _initWebViewController();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  // Safe setState that checks if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (_isMounted) {
      setState(fn);
    }
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ThemeManager',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'dark') {
            widget.onThemeChange('dark');
          } else if (message.message == 'light') {
            widget.onThemeChange('light');
          } else if (message.message == 'system') {
            widget.onThemeChange('system');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _safeSetState(() {
              _isLoading = true;
            });
            print("Sheet WebView page started: $url");
          },
          onPageFinished: (String url) {
            _safeSetState(() {
              _isLoading = false;
            });
            print("Sheet WebView page finished: $url");
          },
          onWebResourceError: (WebResourceError error) {
            print("Sheet WebView error: ${error.description}");
            _safeSetState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print("Sheet WebView navigation to: ${request.url}");

            if (request.url.startsWith('dark-mode://')) {
              widget.onThemeChange('dark');
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('light-mode://')) {
              widget.onThemeChange('light');
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('system-mode://')) {
              widget.onThemeChange('system');
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('new-web://')) {
              widget.onNavigateToTestPage(request.url);
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('new-sheet://')) {
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );
    
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9, 
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Web View",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),

                  if (_isLoading)
                    Container(
                      color: widget.isDarkMode ? Colors.black : Colors.white,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}