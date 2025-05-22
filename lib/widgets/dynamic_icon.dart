// lib/widgets/dynamic_icon.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DynamicIcon extends StatelessWidget {
  final String iconUrl;
  final double size;
  final Color? color;
  final Color? loadingColor;
  final Widget? fallbackIcon;
  final bool showLoading;

  const DynamicIcon({
    super.key,
    required this.iconUrl,
    this.size = 24.0,
    this.color,
    this.loadingColor,
    this.fallbackIcon,
    this.showLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: iconUrl,
        width: size,
        height: size,
        color: color,
        fit: BoxFit.contain,
        placeholder: showLoading ? (context, url) => _buildLoading() : null,
        errorWidget: (context, url, error) => _buildFallback(),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: SizedBox(
        width: size * 0.6,
        height: size * 0.6,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(
            loadingColor ?? Colors.grey.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return fallbackIcon ??
        Icon(
          Icons.image_not_supported_outlined,
          size: size,
          color: color ?? Colors.grey,
        );
  }
}