import 'dart:math';
import 'package:flutter/material.dart';

/// A tiny animated llama that runs while streaming, then rests when done.
class StreamingLlama extends StatefulWidget {
  final bool isRunning;

  const StreamingLlama({super.key, this.isRunning = true});

  @override
  State<StreamingLlama> createState() => _StreamingLlamaState();
}

class _StreamingLlamaState extends State<StreamingLlama>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isRunning ? 300 : 2500),
    )..repeat();
  }

  @override
  void didUpdateWidget(StreamingLlama old) {
    super.didUpdateWidget(old);
    if (widget.isRunning != old.isRunning) {
      _controller.duration =
          Duration(milliseconds: widget.isRunning ? 300 : 2500);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(22, 16),
          painter: _LlamaPainter(
            phase: _controller.value,
            isRunning: widget.isRunning,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        );
      },
    );
  }
}

class _LlamaPainter extends CustomPainter {
  final double phase;
  final bool isRunning;
  final Color color;

  _LlamaPainter({
    required this.phase,
    required this.isRunning,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final bounce = isRunning ? sin(phase * 2 * pi) * 1.2 : 0.0;
    final breathe = !isRunning ? sin(phase * 2 * pi) * 0.25 : 0.0;
    final by = bounce + breathe;

    // ── dust (running only) ──
    if (isRunning) {
      for (int i = 0; i < 3; i++) {
        final p = (phase + i * 0.33) % 1.0;
        canvas.drawCircle(
          Offset(4 - p * 7, 13 + by + p * 1.5),
          0.5 + p * 0.9,
          Paint()..color = color.withValues(alpha: (1.0 - p) * 0.2),
        );
      }
    }

    // ── fluffy body (large, round — the dominant shape) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 5.5 + by, 10, 5.5),
        const Radius.circular(2.8),
      ),
      fill,
    );

    // ── neck (SHORT and thick — not a giraffe!) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12.5, 3.5 + by, 2.8, 4),
        const Radius.circular(1.4),
      ),
      fill,
    );

    // ── head (round, close to body) ──
    canvas.drawOval(
      Rect.fromCenter(center: Offset(16, 3 + by), width: 5, height: 4.2),
      fill,
    );

    // ── ears (upright, banana-shaped) ──
    final ear = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // left ear
    final leftEar = Path()
      ..moveTo(14.8, 1.5 + by)
      ..quadraticBezierTo(14.2, -0.5 + by, 14.8, -0.2 + by);
    canvas.drawPath(leftEar, ear);
    // right ear
    final rightEar = Path()
      ..moveTo(16.8, 1 + by)
      ..quadraticBezierTo(17.2, -1 + by, 17.8, -0.2 + by);
    canvas.drawPath(rightEar, ear);

    // ── eye ──
    if (isRunning) {
      canvas.drawCircle(
        Offset(17.5, 2.5 + by), 0.7,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    } else {
      // resting: happy closed eye
      final eyePath = Path()
        ..moveTo(16.8, 2.8 + by)
        ..quadraticBezierTo(17.5, 2.2 + by, 18.2, 2.8 + by);
      canvas.drawPath(eyePath, Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // ── legs (short and stubby) ──
    final leg = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const footY = 14.5;

    if (isRunning) {
      final lp = phase * 2 * pi;
      _leg(canvas, 12, 10.5 + by, sin(lp) * 2.8, footY, leg);
      _leg(canvas, 10.5, 10.5 + by, sin(lp + pi) * 2.8, footY, leg);
      _leg(canvas, 7, 10.5 + by, sin(lp + pi * 0.6) * 2.5, footY, leg);
      _leg(canvas, 5.5, 10.5 + by, sin(lp + pi * 1.6) * 2.5, footY, leg);
    } else {
      _leg(canvas, 12, 10.5 + by, 0, footY, leg);
      _leg(canvas, 10.5, 10.5 + by, 0, footY, leg);
      _leg(canvas, 7, 10.5 + by, 0, footY, leg);
      _leg(canvas, 5.5, 10.5 + by, 0, footY, leg);
    }

    // ── tail (small puff) ──
    final tailWag = isRunning ? sin(phase * 4 * pi) * 1.8 : sin(phase * 2 * pi) * 0.3;
    canvas.drawCircle(
      Offset(3.5, 6.5 + by + tailWag * 0.3), 1.5,
      Paint()..color = color.withValues(alpha: 0.6),
    );
  }

  void _leg(Canvas c, double x, double top, double off, double foot, Paint p) {
    c.drawLine(Offset(x, top), Offset(x + off, foot), p);
  }

  @override
  bool shouldRepaint(_LlamaPainter old) =>
      phase != old.phase || isRunning != old.isRunning || color != old.color;
}
