// lib/widgets/connection_status_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ERPForever/services/internet_connection_service.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final Widget child;
  final bool showPersistentBanner;
  
  const ConnectionStatusWidget({
    super.key,
    required this.child,
    this.showPersistentBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<InternetConnectionService>(
      builder: (context, connectionService, _) {
        return Scaffold(
          body: Stack(
            children: [
              child,
              if (!connectionService.isConnected && showPersistentBanner)
                _buildConnectionBanner(context, connectionService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionBanner(
    BuildContext context, 
    InternetConnectionService connectionService,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDetailedConnectionDialog(context, connectionService),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No Internet Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildRetryButton(context, connectionService),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton(
    BuildContext context, 
    InternetConnectionService connectionService,
  ) {
    return InkWell(
      onTap: () => _handleRetry(context, connectionService),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRetry(
    BuildContext context, 
    InternetConnectionService connectionService,
  ) async {
    // Show loading state
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text('Checking connection...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue.shade600,
      ),
    );

    // Perform retry
    final success = await connectionService.retryConnection();
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Connection restored!'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Please check your network.' ,),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red.shade600,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => _showDetailedConnectionDialog(context, connectionService),
          ),
        ),
      );
    }
  }

  Future<void> _showDetailedConnectionDialog(
    BuildContext context,
    InternetConnectionService connectionService,
  ) async {
    final connectionType = await connectionService.getConnectionType();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text('Connection Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connectionService.getConnectionMessage(),
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Status', 'Disconnected', Colors.red),
            _buildStatusRow('Connection Type', connectionType, Colors.grey),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troubleshooting Tips:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                 Text(
  '• Check if WiFi or mobile data is enabled\n'
  '• Try switching between WiFi and mobile data\n'
  '• Restart your router or modem\n'
  '• Check if other apps can access the internet',
  softWrap: true,
  overflow: TextOverflow.visible,
  style: TextStyle(
    fontSize: 14,
    color: Colors.blue.shade700,
  ),
)
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleRetry(context, connectionService);
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simplified widget for areas where you just want to show connection status
class SimpleConnectionIndicator extends StatelessWidget {
  const SimpleConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InternetConnectionService>(
      builder: (context, connectionService, _) {
        if (connectionService.isConnected) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}