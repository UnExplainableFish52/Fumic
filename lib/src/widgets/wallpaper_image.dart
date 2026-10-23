import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/visualizer_settings.dart';

/// A stable decode size avoids retaining a separate full-resolution image for
/// every window size or screen that displays the same wallpaper.
class WallpaperImage extends StatefulWidget {
  const WallpaperImage({
    super.key,
    required this.settings,
    this.cacheWidth = 1920,
    this.errorPlaceholder,
  });

  final VisualizerSettings settings;
  final int cacheWidth;
  final Widget? errorPlaceholder;

  @override
  State<WallpaperImage> createState() => _WallpaperImageState();
}

class _WallpaperImageState extends State<WallpaperImage> {
  late ImageProvider<Object> _primary;
  late ImageProvider<Object> _preset;
  ImageConfiguration _configuration = ImageConfiguration.empty;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  void _configure() {
    ImageProvider<Object> resized(ImageProvider<Object> source) => ResizeImage(
      source,
      width: widget.cacheWidth,
      height: (widget.cacheWidth * 9 / 16).round(),
      policy: ResizeImagePolicy.fit,
    );
    _preset = resized(AssetImage(widget.settings.background.asset));
    final path = widget.settings.customBackgroundPath;
    _primary = path == null ? _preset : resized(FileImage(File(path)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configuration = createLocalImageConfiguration(context);
  }

  @override
  void didUpdateWidget(covariant WallpaperImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldProviders = {_primary, _preset};
    _configure();
    _release(oldProviders.difference({_primary, _preset}));
  }

  void _release(Set<ImageProvider<Object>> providers) {
    if (providers.isEmpty) return;
    final configuration = _configuration;
    // Let outgoing Image widgets detach first. Only the obsolete wallpaper's
    // cache entries are evicted; artwork and current images remain usable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final provider in providers) {
        unawaited(() async {
          try {
            final key = await provider.obtainKey(configuration);
            PaintingBinding.instance.imageCache.evict(key, includeLive: false);
          } on Object {
            // Cleanup of a missing/corrupt image must not interrupt rendering.
          }
        }());
      }
    });
  }

  @override
  void dispose() {
    _release({_primary, _preset});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.errorPlaceholder ?? const ColoredBox(color: Color(0xFF111622));
    final preset = Image(
      image: _preset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
    if (widget.settings.customBackgroundPath == null) return preset;
    return Image(
      image: _primary,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          widget.errorPlaceholder ?? preset,
    );
  }
}
