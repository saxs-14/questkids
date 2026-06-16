import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// An animated, GPU-accelerated background driven by the `shaders/aurora.frag`
/// GLSL fragment shader.
///
/// The shader runs per-pixel on Impeller (mobile) and CanvasKit (web). If the
/// shader fails to compile/load on any platform, this widget transparently
/// falls back to a static [LinearGradient] of the same colours, so a screen is
/// never left blank.
///
/// Pass exactly three [colors] (base → mid → highlight). [child] is painted on
/// top of the animated backdrop.
class ShaderBackground extends StatefulWidget {
  final List<Color> colors;
  final Widget? child;

  /// When false, skips the shader and always uses the gradient fallback
  /// (useful for reduced-motion / low-end devices).
  final bool animated;

  const ShaderBackground({
    super.key,
    required this.colors,
    this.child,
    this.animated = true,
  }) : assert(colors.length == 3, 'ShaderBackground needs exactly 3 colors');

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin {
  // Cache the compiled program across instances — loading is async + one-off.
  static ui.FragmentProgram? _program;
  static bool _loadFailed = false;

  ui.FragmentShader? _shader;
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    if (widget.animated) _init();
  }

  Future<void> _init() async {
    if (_loadFailed) return;
    try {
      _program ??= await ui.FragmentProgram.fromAsset('shaders/aurora.frag');
      if (!mounted) return;
      setState(() => _shader = _program!.fragmentShader());
      _ticker = createTicker((elapsed) {
        _time.value = elapsed.inMicroseconds / 1e6;
      })..start();
    } catch (_) {
      _loadFailed = true; // never retry; gradient fallback is fine
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fallback gradient (also shown while the shader is still loading).
    if (_shader == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.colors,
          ),
        ),
        child: widget.child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _time,
            builder: (_, t, __) => CustomPaint(
              painter: _ShaderPainter(_shader!, t, widget.colors),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final List<Color> colors;

  _ShaderPainter(this.shader, this.time, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      // colour components are already 0..1 doubles in the modern Color API
      ..setFloat(3, colors[0].r)
      ..setFloat(4, colors[0].g)
      ..setFloat(5, colors[0].b)
      ..setFloat(6, colors[1].r)
      ..setFloat(7, colors[1].g)
      ..setFloat(8, colors[1].b)
      ..setFloat(9, colors[2].r)
      ..setFloat(10, colors[2].g)
      ..setFloat(11, colors[2].b);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => old.time != time;
}
