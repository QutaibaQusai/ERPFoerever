// lib/pages/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/services/webview_controller_manager.dart';
import 'package:ERPForever/widgets/dynamic_bottom_navigation.dart';
import 'package:ERPForever/widgets/dynamic_app_bar.dart';
import 'package:ERPForever/widgets/loading_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late ConfigService _configService;
  late WebViewControllerManager _controllerManager;
  
  final Map<int, bool> _loadingStates = {};

  @override
  void initState() {
    super.initState();
    _configService = ConfigService();
    _controllerManager = WebViewControllerManager();
    
    _initializeLoadingStates();
  }

  void _initializeLoadingStates() {
    final config = _configService.config;
    if (config != null) {
      for (int i = 0; i < config.mainIcons.length; i++) {
        _loadingStates[i] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        if (!configService.isLoaded) {
          return const Scaffold(
            body: Center(
              child: LoadingWidget(message: "Loading configuration..."),
            ),
          );
        }

        if (configService.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configuration Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      configService.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => configService.reloadConfig(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildMainScaffold(configService.config!);
      },
    );
  }

  Widget _buildMainScaffold(config) {
    return Scaffold(
      appBar: DynamicAppBar(selectedIndex: _selectedIndex),
      body: _buildBody(config),
      bottomNavigationBar: DynamicBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
 floatingActionButton: null, // Remove separate FAB

    );
  }

  Widget _buildBody(config) {
    if (config.mainIcons.isEmpty) {
      return const Center(
        child: Text('No navigation items configured'),
      );
    }

    return IndexedStack(
      index: _selectedIndex,
      children: List.generate(
        config.mainIcons.length,
        (index) => _buildTabContent(index, config.mainIcons[index]),
      ),
    );
  }

  Widget _buildTabContent(int index, mainIcon) {
    if (mainIcon.linkType == 'sheet_webview') {
      return const Center(
        child: Text('This tab opens as a sheet'),
      );
    }

    return Stack(
      children: [
        _buildWebView(index, mainIcon.link),
        if (_loadingStates[index] == true) const LoadingWidget(),
      ],
    );
  }

  Widget _buildWebView(int index, String url) {
    final controller = _controllerManager.getController(index, url);
    
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _loadingStates[index] = true;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _loadingStates[index] = false;
          });
        },
        onWebResourceError: (WebResourceError error) {
          setState(() {
            _loadingStates[index] = false;
          });
        },
        onNavigationRequest: (NavigationRequest request) {
          return _handleNavigationRequest(request);
        },
      ),
    );

    return WebViewWidget(controller: controller);
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint("Navigation request: ${request.url}");

    if (request.url.startsWith('dark-mode://') ||
        request.url.startsWith('light-mode://') ||
        request.url.startsWith('system-mode://')) {
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('new-web://')) {
      _handleNewWebNavigation(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('new-sheet://')) {
      _handleSheetNavigation(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.contains('barcode') || request.url.contains('scan')) {
      _handleBarcodeScanning(request.url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleNewWebNavigation(String url) {
    String targetUrl = 'https://www.erpforever.com/mobile/test';
    
    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-web://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint("Error parsing URL parameters: $e");
      }
    }

    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'regular_webview',
      title: 'Web View',
    );
  }

  void _handleSheetNavigation(String url) {
    String targetUrl = 'https://mujeer.com';
    
    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-sheet://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint("Error parsing URL parameters: $e");
      }
    }

    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'sheet_webview',
      title: 'Web View',
    );
  }

  void _handleBarcodeScanning(String url) {
    debugPrint("Barcode scanning triggered: $url");
  }

  void _onItemTapped(int index) {
    final config = _configService.config;
    if (config == null) return;

    final item = config.mainIcons[index];
    
    if (item.linkType == 'sheet_webview') {
      WebViewService().navigate(
        context,
        url: item.link,
        linkType: item.linkType,
        title: item.title,
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }


}