// lib/widgets/connection_status_widget.dart - MODERNIZED UI
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
                _buildModernConnectionBanner(context, connectionService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernConnectionBanner(
    BuildContext context, 
    InternetConnectionService connectionService,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            // Modern glassmorphism effect
            color: isDarkMode 
                ? Colors.red.shade900.withOpacity(0.9)
                : Colors.red.shade50.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode 
                  ? Colors.red.shade700.withOpacity(0.6)
                  : Colors.red.shade200.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade900.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.7),
                blurRadius: 10,
                offset: const Offset(0, -2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showModernConnectionDialog(context, connectionService),
              child: Row(
                children: [
                  // Modern animated icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? Colors.red.shade600.withOpacity(0.3)
                          : Colors.red.shade100.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedBuilder(
                      animation: _createPulseAnimation(),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.9 + (_createPulseAnimation().value * 0.2),
                          child: Icon(
                            Icons.wifi_off_rounded,
                            color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600,
                            size: 22,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Modern text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: isDarkMode ? Colors.red.shade200 : Colors.red.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to retry or see troubleshooting tips',
                          style: TextStyle(
                            color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Modern retry button
                  _buildModernRetryButton(context, connectionService, isDarkMode),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Create pulse animation for the wifi icon
  Animation<double> _createPulseAnimation() {
    // This is a simplified version - in a real implementation,
    // you'd want to use an AnimationController in a StatefulWidget
    return AlwaysStoppedAnimation(0.5);
  }

  Widget _buildModernRetryButton(
    BuildContext context, 
    InternetConnectionService connectionService,
    bool isDarkMode,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
              ? [Colors.red.shade600, Colors.red.shade700]
              : [Colors.red.shade500, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade600.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleRetry(context, connectionService),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRetry(
    BuildContext context, 
    InternetConnectionService connectionService,
  ) async {
    // Modern loading feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Text(
              'Checking connection...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    final success = await connectionService.retryConnection();
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    if (success) {
      // Modern success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connection Restored!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'You\'re back online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      // Modern error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Still No Connection',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Check your network settings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Help',
            textColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
            onPressed: () => _showModernConnectionDialog(context, connectionService),
          ),
        ),
      );
    }
  }

  Future<void> _showModernConnectionDialog(
    BuildContext context,
    InternetConnectionService connectionService,
  ) async {
    final connectionType = await connectionService.getConnectionType();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 16),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern header with icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? Colors.red.shade900.withOpacity(0.3)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Connection Issue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                connectionService.getConnectionMessage(),
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Modern status cards
              // Container(
              //   padding: const EdgeInsets.all(16),
              //   decoration: BoxDecoration(
              //     color: isDarkMode 
              //         ? Colors.grey.shade800.withOpacity(0.5)
              //         : Colors.grey.shade50,
              //     borderRadius: BorderRadius.circular(16),
              //     border: Border.all(
              //       color: isDarkMode 
              //           ? Colors.grey.shade700
              //           : Colors.grey.shade200,
              //     ),
              //   ),
              //   child: Column(
              //     children: [
              //       _buildModernStatusRow('Status', 'Disconnected', Colors.red, isDarkMode),
              //       const SizedBox(height: 12),
              //       _buildModernStatusRow('Connection Type', connectionType, Colors.grey, isDarkMode),
              //     ],
              //   ),
              // ),
             
             
              const SizedBox(height: 24),
              
           
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade500, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade600.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _handleRetry(context, connectionService);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildModernStatusRow(String label, String value, Color valueColor, bool isDarkMode) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontWeight: FontWeight.w500,
  //           color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
  //           fontSize: 14,
  //         ),
  //       ),
  //       Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //         decoration: BoxDecoration(
  //           color: valueColor.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(8),
  //           border: Border.all(
  //             color: valueColor.withOpacity(0.3),
  //           ),
  //         ),
  //         child: Text(
  //           value,
  //           style: TextStyle(
  //             fontWeight: FontWeight.w600,
  //             color: valueColor,
  //             fontSize: 14,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

 

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

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Colors.red.shade900.withOpacity(0.9)
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode 
                  ? Colors.red.shade700.withOpacity(0.6)
                  : Colors.red.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade900.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}