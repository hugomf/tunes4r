import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A reusable widget that provides optimized album art display with Flutter's built-in caching
/// Uses MemoryImage for automatic caching and adds placeholder/gradient fallbacks
class CachedAlbumArt extends StatelessWidget {
  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool useHero;
  final String? heroTag;

  const CachedAlbumArt({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.useHero = false,
    this.heroTag,
  });

  Widget _buildImage() {
    final image = Image.memory(
      bytes,
      fit: fit,
      // Flutter automatically caches these images
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Album art loading error: $error');
        return _buildPlaceholder();
      },
    );

    if (borderRadius == BorderRadius.zero) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: image,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667DB6), // Blue
            Color(0xFF0082C8), // Blue darker
            Color(0xFF00897B), // Teal
            Color(0xFF43A047), // Green
          ],
          stops: [0.0, 0.33, 0.67, 1.0],
        ),
      ),
      child: const Icon(
        Icons.album,
        color: Colors.white70,
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildImage();

    // Apply sizing constraints if provided
    if (width != null || height != null) {
      imageWidget = SizedBox(
        width: width,
        height: height,
        child: imageWidget,
      );
    }

    // Wrap in Hero for animations if requested
    if (useHero && heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// A convenience widget for when album art might be null
/// Falls back to a placeholder gradient with music icon
class CachedAlbumArtOrPlaceholder extends StatelessWidget {
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool useHero;
  final String? heroTag;

  const CachedAlbumArtOrPlaceholder({
    super.key,
    this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.useHero = false,
    this.heroTag,
  });

  Widget _buildPlaceholder() {
    Widget container = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667DB6), // Blue
            Color(0xFF0082C8), // Blue darker
            Color(0xFF00897B), // Teal
            Color(0xFF43A047), // Green
          ],
          stops: [0.0, 0.33, 0.67, 1.0],
        ),
      ),
      child: const Icon(
        Icons.album,
        color: Colors.white70,
        size: 32,
      ),
    );

    // Apply border radius to placeholder too
    if (borderRadius != BorderRadius.zero) {
      container = ClipRRect(
        borderRadius: borderRadius,
        child: container,
      );
    }

    // Apply sizing
    if (width != null || height != null) {
      container = SizedBox(
        width: width,
        height: height,
        child: container,
      );
    }

    return container;
  }

  @override
  Widget build(BuildContext context) {
    if (bytes == null || bytes!.isEmpty) {
      return _buildPlaceholder();
    }

    return CachedAlbumArt(
      key: key,
      bytes: bytes!,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      useHero: useHero,
      heroTag: heroTag,
    );
  }
}

/// Enhanced image loading with fade-in animation for better UX
class FadeInAlbumArt extends StatelessWidget {
  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Duration fadeDuration;

  const FadeInAlbumArt({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: fadeDuration,
      child: CachedAlbumArt(
        bytes: bytes,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
      ),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
    );
  }
}
