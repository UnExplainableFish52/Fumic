import 'dart:async';

import 'package:flutter/material.dart';

import '../models/visualizer_settings.dart';

/// Activity and visibility belong to the player surface, not playback-position
/// updates. Hidden controls have no active playback listener or focus targets.
class FullPlayerSurface extends StatefulWidget {
  const FullPlayerSurface({
    super.key,
    required this.settings,
    required this.content,
    required this.controls,
    this.controlsBackdrop,
    this.activity,
  });
  final VisualizerSettings settings;
  final Widget content;
  final Widget controls;
  final Widget? controlsBackdrop;
  final Listenable? activity;

  @override
  State<FullPlayerSurface> createState() => _FullPlayerSurfaceState();
}

class _FullPlayerSurfaceState extends State<FullPlayerSurface> {
  Timer? _hideTimer;
  bool _visible = true;
  bool _active = true;
  bool _overControls = false;
  bool _controlsFocused = false;
  final Set<int> _pressedPointers = {};

  @override
  void initState() {
    super.initState();
    _visible = widget.settings.showPlayerControls;
    widget.activity?.addListener(_activity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (!_active && active) _visible = widget.settings.showPlayerControls;
    _active = active;
    if (!active) {
      _pressedPointers.clear();
      _overControls = false;
      _controlsFocused = false;
    }
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant FullPlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) {
      oldWidget.activity?.removeListener(_activity);
      widget.activity?.addListener(_activity);
    }
    if (oldWidget.settings.showPlayerControls !=
            widget.settings.showPlayerControls ||
        oldWidget.settings.effectivePlayerControlsHideDelaySeconds !=
            widget.settings.effectivePlayerControlsHideDelaySeconds) {
      _visible = widget.settings.showPlayerControls;
      _armTimer();
    }
  }

  void _activity() {
    if (!mounted || !_active || !widget.settings.showPlayerControls) return;
    if (!_visible) setState(() => _visible = true);
    _armTimer();
  }

  void _armTimer() {
    _hideTimer?.cancel();
    final seconds = widget.settings.effectivePlayerControlsHideDelaySeconds;
    if (!_active ||
        !_visible ||
        !widget.settings.showPlayerControls ||
        seconds == 0 ||
        _overControls ||
        _pressedPointers.isNotEmpty ||
        _controlsFocused) {
      return;
    }
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      // A speed menu or another modal route is still an active interaction.
      if (ModalRoute.of(context)?.isCurrent == false) {
        _armTimer();
        return;
      }
      setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.activity?.removeListener(_activity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: !_visible && widget.settings.showPlayerControls
        ? SystemMouseCursors.none
        : MouseCursor.defer,
    onHover: (_) => _activity(),
    onEnter: (_) => _activity(),
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pressedPointers.add(event.pointer);
        _activity();
      },
      onPointerUp: (event) {
        _pressedPointers.remove(event.pointer);
        _activity();
      },
      onPointerCancel: (event) {
        _pressedPointers.remove(event.pointer);
        _activity();
      },
      onPointerMove: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.content,
          if (widget.controlsBackdrop != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey('full-player-controls-backdrop'),
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: widget.controlsBackdrop,
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: IgnorePointer(
              ignoring: !_visible,
              child: ExcludeFocus(
                excluding: !_visible,
                child: ExcludeSemantics(
                  excluding: !_visible,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: _visible
                        ? MouseRegion(
                            key: const ValueKey('full-player-controls'),
                            onEnter: (_) {
                              _overControls = true;
                              _armTimer();
                            },
                            onExit: (_) {
                              _overControls = false;
                              _armTimer();
                            },
                            child: Focus(
                              onFocusChange: (focused) {
                                _controlsFocused = focused;
                                if (mounted) _armTimer();
                              },
                              child: widget.controls,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
